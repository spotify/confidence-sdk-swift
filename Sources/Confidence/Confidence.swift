// swiftlint:disable file_length
import Foundation
import Combine
import os

// swiftlint:disable:next type_body_length
public class Confidence: ConfidenceEventSender {
    // User configurations
    private let clientSecret: String
    private let region: ConfidenceRegion
    private let debugLogger: DebugLogger?

    // Resources related to managing context and flags
    private let parentContextProvider: ConfidenceContextProvider?
    private let contextManager: ContextManager
    private var cache = FlagResolution.EMPTY

    // Core components managing internal SDK functionality
    private let eventSenderEngine: EventSenderEngine
    private let storage: Storage
    private let flagApplier: FlagApplier

    // Synchronization and task management resources
    private var cancellables = Set<AnyCancellable>()
    private let cacheQueue = DispatchQueue(label: "com.confidence.queue.cache")
    private var taskManager = TaskManager()

    // Internal for testing
    internal let remoteFlagResolver: ConfidenceResolveClient

    public static let sdkId: String = "SDK_ID_SWIFT_CONFIDENCE"

    required init(
        clientSecret: String,
        region: ConfidenceRegion,
        eventSenderEngine: EventSenderEngine,
        flagApplier: FlagApplier,
        remoteFlagResolver: ConfidenceResolveClient,
        storage: Storage,
        context: ConfidenceStruct = [:],
        parent: ConfidenceEventSender? = nil,
        visitorId: String? = nil,
        debugLogger: DebugLogger?
    ) {
        self.eventSenderEngine = eventSenderEngine
        self.clientSecret = clientSecret
        self.region = region
        self.storage = storage
        self.contextManager = ContextManager(initialContext: context)
        self.parentContextProvider = parent
        self.flagApplier = flagApplier
        self.remoteFlagResolver = remoteFlagResolver
        self.debugLogger = debugLogger
        if let visitorId {
            putContextLocal(context: ["visitor_id": ConfidenceValue.init(string: visitorId)])
        }
    }

    /**
    Activating the cache means that the flag data on disk is loaded into memory, so consumers can access flag values.
    Errors can be thrown if something goes wrong access data on disk.
    */
    public func activate() throws {
        try cacheQueue.sync {  [weak self] in
            guard let self = self else {
                return
            }
            let savedFlags = try storage.load(defaultValue: FlagResolution.EMPTY)
            cache = savedFlags
        }
    }

    /**
    Fetch latest flag evaluations and store them on disk. Regardless of the fetch outcome (success or failure), this
    function activates the cache after the fetch.
    Activating the cache means that the flag data on disk is loaded into memory, so consumers can access flag values.
    Fetching is best-effort, so no error is propagated. Errors can still be thrown if something goes wrong access data
    on disk.
    */
    public func fetchAndActivate() async throws {
        await asyncFetch()
        try activate()
    }

    /**
    Fetch latest flag evaluations and store them on disk. Note that "activate" must be called for this data to be
    made available in the app session.
    */
    public func asyncFetch() async {
        do {
            try await internalFetch()
        } catch {
            debugLogger?.logMessage(
                message: "\(error )",
                isWarning: true
            )
        }
    }

    private func internalFetch() async throws {
        let context = getContext()
        let resolvedFlags = try await remoteFlagResolver.resolve(ctx: context)
        let resolution = FlagResolution(
            context: context,
            flags: resolvedFlags.resolvedValues,
            resolveToken: resolvedFlags.resolveToken ?? ""
        )
        try storage.save(data: resolution)
    }

    /**
    Returns true if any flag is found in storage.
    */
    public func isStorageEmpty() -> Bool {
        return storage.isEmpty()
    }

    /**
    Get evaluation data for a specific flag. Evaluation data includes the variant's name and reason/error information.
    - Parameter key:expects dot-notation to retrieve a specific entry in the flag's value, e.g. "flagname.myentry"
    - Parameter defaultValue: returned in case of errors or in case of the variant's rule indicating to use the
    default value.
    */
    public func getEvaluation<T>(key: String, defaultValue: T) -> Evaluation<T> {
        cacheQueue.sync {  [weak self] in
            guard let self = self else {
                return Evaluation(
                    value: defaultValue,
                    variant: nil,
                    reason: .error,
                    errorCode: .providerNotReady,
                    errorMessage: "Confidence instance deallocated before end of evaluation"
                )
            }
            return self.cache.evaluate(
                flagName: key,
                defaultValue: defaultValue,
                context: getContext(),
                flagApplier: flagApplier,
                debugLogger: debugLogger
            )
        }
    }

    /**
    Get the value for a specific flag.
    - Parameter key:expects dot-notation to retrieve a specific entry in the flag's value, e.g. "flagname.myentry"
    - Parameter defaultValue: returned in case of errors or in case of the variant's rule indicating to use the
    default value.
    */
    public func getValue<T>(key: String, defaultValue: T) -> T {
        return getEvaluation(key: key, defaultValue: defaultValue).value
    }

    public func getContext() -> ConfidenceStruct {
        let parentContext = parentContextProvider?.getContext() ?? [:]
        return contextManager.getContext(parentContext: parentContext)
    }

    public func putContextAndWait(key: String, value: ConfidenceValue) async {
        taskManager.currentTask = Task {
            let newContext = contextManager.updateContext(withValues: [key: value], removedKeys: [])
            do {
                try await self.fetchAndActivate()
                debugLogger?.logContext(action: "PutContext", context: newContext)
            } catch {
                debugLogger?.logMessage(message: "Error when putting context: \(error)", isWarning: true)
            }
        }
        await awaitReconciliation()
    }

    public func putContextAndWait(context: ConfidenceStruct, removedKeys: [String] = []) async {
        taskManager.currentTask = Task {
            let newContext = contextManager.updateContext(withValues: context, removedKeys: removedKeys)
            do {
                try await self.fetchAndActivate()
                debugLogger?.logContext(action: "PutContext", context: newContext)
            } catch {
                debugLogger?.logMessage(message: "Error when putting context: \(error)", isWarning: true)
            }
        }
        await awaitReconciliation()
    }

    public func putContextAndWait(context: ConfidenceStruct) async {
        taskManager.currentTask = Task {
            let newContext = contextManager.updateContext(withValues: context, removedKeys: [])
            do {
                try await fetchAndActivate()
                debugLogger?.logContext(
                    action: "PutContext",
                    context: newContext)
            } catch {
                debugLogger?.logMessage(
                    message: "Error when putting context: \(error)",
                    isWarning: true)
            }
        }
        await awaitReconciliation()
    }

    public func removeContextAndWait(key: String) async {
        taskManager.currentTask = Task {
            let newContext = contextManager.updateContext(withValues: [:], removedKeys: [key])
            do {
                try await self.fetchAndActivate()
                debugLogger?.logContext(
                    action: "RemoveContext",
                    context: newContext)
            } catch {
                debugLogger?.logMessage(
                    message: "Error when removing context key: \(error)",
                    isWarning: true)
            }
        }
        await awaitReconciliation()
    }

    /**
    Adds/override entry to local context data. Does not trigger fetchAndActivate after the context change.
    */
    public func putContextLocal(context: ConfidenceStruct, removeKeys removedKeys: [String] = []) {
        let newContext = contextManager.updateContext(withValues: context, removedKeys: removedKeys)
        debugLogger?.logContext(
            action: "PutContextLocal",
            context: newContext)
    }

    public func putContext(key: String, value: ConfidenceValue) {
        taskManager.currentTask = Task {
            await putContextAndWait(key: key, value: value)
        }
    }

    public func putContext(context: ConfidenceStruct) {
        taskManager.currentTask = Task {
            await putContextAndWait(context: context)
        }
    }

    public func putContext(context: ConfidenceStruct, removeKeys removedKeys: [String] = []) {
        taskManager.currentTask = Task {
            await putContextAndWait(context: context, removedKeys: removedKeys)
        }
    }

    public func removeContext(key: String) {
        taskManager.currentTask = Task {
            await removeContextAndWait(key: key)
        }
    }

    public func putContext(context: ConfidenceStruct, removedKeys: [String]) {
        taskManager.currentTask = Task {
            let newContext = contextManager.updateContext(withValues: context, removedKeys: removedKeys)
            do {
                try await self.fetchAndActivate()
                debugLogger?.logContext(
                    action: "RemoveContext",
                    context: newContext)
            } catch {
                debugLogger?.logMessage(
                    message: "Error when putting context: \(error)",
                    isWarning: true)
            }
        }
    }

    /**
    Ensures all the already-started context changes prior to this function have been reconciliated
    */
    public func awaitReconciliation() async {
        await taskManager.awaitReconciliation()
    }

    public func withContext(_ context: ConfidenceStruct) -> ConfidenceEventSender {
        return Self.init(
            clientSecret: clientSecret,
            region: region,
            eventSenderEngine: eventSenderEngine,
            flagApplier: flagApplier,
            remoteFlagResolver: remoteFlagResolver,
            storage: storage,
            context: context,
            parent: self,
            debugLogger: debugLogger
        )
    }

    public func track(producer: ConfidenceProducer) {
        if let eventProducer = producer as? ConfidenceEventProducer {
            eventProducer.produceEvents()
                .sink { [weak self] event in
                    guard let self = self else {
                        return
                    }
                    do {
                        try self.track(eventName: event.name, data: event.data)
                        if event.shouldFlush {
                            eventSenderEngine.flush()
                        }
                    } catch {
                        Logger(subsystem: "com.confidence", category: "track").warning(
                            "Error from EventProducer, failed to track event: \(event.name)")
                    }
                }
                .store(in: &cancellables)
        }

        if let contextProducer = producer as? ConfidenceContextProducer {
            contextProducer.produceContexts()
                .sink { [weak self] context in
                    Task { [weak self] in
                        guard let self = self else { return }
                        await self.putContextAndWait(context: context)
                    }
                }
                .store(in: &cancellables)
        }
    }

    public func track(eventName: String, data: ConfidenceStruct) throws {
        try eventSenderEngine.emit(
            eventName: eventName,
            data: data,
            context: getContext()
        )
    }

    public func flush() {
        eventSenderEngine.flush()
    }
}

private class ContextManager {
    private var context: ConfidenceStruct = [:]
    private var removedContextKeys: Set<String> = Set()
    private let contextQueue = DispatchQueue(label: "com.confidence.queue.context")

    public init(initialContext: ConfidenceStruct) {
        context = initialContext
    }

    func updateContext(withValues: ConfidenceStruct, removedKeys: [String]) -> ConfidenceStruct {
        contextQueue.sync {  [weak self] in
            guard let self = self else {
                return [:]
            }
            var map = self.context
            for removedKey in removedKeys {
                map.removeValue(forKey: removedKey)
                removedContextKeys.insert(removedKey)
            }
            for entry in withValues {
                map.updateValue(entry.value, forKey: entry.key)
            }
            self.context = map
            return self.context
        }
    }

    func getContext(parentContext: ConfidenceStruct) -> ConfidenceStruct {
        contextQueue.sync {  [weak self] in
            guard let self = self else {
                return [:]
            }
            var reconciledCtx = parentContext.filter {
                !self.removedContextKeys.contains($0.key)
            }
            context.forEach { entry in
                reconciledCtx.updateValue(entry.value, forKey: entry.key)
            }
            return reconciledCtx
        }
    }
}

extension Confidence {
    public class Builder {
        // Must be configured or configured automatically
        internal let clientSecret: String
        internal let eventStorage: EventStorage
        internal let visitorId = VisitorUtil().getId()
        internal let loggerLevel: LoggerLevel

        // Can be configured
        internal var region: ConfidenceRegion = .global
        internal var initialContext: ConfidenceStruct = [:]
        internal var timeout: Double = 10

        // Injectable for testing
        internal var flagApplier: FlagApplier?
        internal var storage: Storage?
        internal var flagResolver: ConfidenceResolveClient?
        internal var debugLogger: DebugLogger?

        /**
        Initialize the builder with the given client secret and logger level. The logger allows to print warnings or
        debugging information to the local console.
        */
        public init(clientSecret: String, loggerLevel: LoggerLevel = .WARN) {
            self.clientSecret = clientSecret
            do {
                eventStorage = try EventStorageImpl()
            } catch {
                eventStorage = EventStorageInMemory()
            }
            self.loggerLevel = loggerLevel
        }

        internal func withFlagResolverClient(flagResolver: ConfidenceResolveClient) -> Builder {
            self.flagResolver = flagResolver
            return self
        }


        internal func withFlagApplier(flagApplier: FlagApplier) -> Builder {
            self.flagApplier = flagApplier
            return self
        }

        internal func withStorage(storage: Storage) -> Builder {
            self.storage = storage
            return self
        }

        internal func withDebugLogger(debugLogger: DebugLogger) -> Builder {
            self.debugLogger = debugLogger
            return self
        }

        /**
        Set the initial context.
        */
        public func withContext(initialContext: ConfidenceStruct) -> Builder {
            self.initialContext = initialContext
            return self
        }

        /**
        Set the region for the network request to the Confidence backend.
        The default is `global` and the requests are automatically routed to the closest server.
        */
        public func withRegion(region: ConfidenceRegion) -> Builder {
            self.region = region
            return self
        }

    /**
    Set the timeout for the network request, defaulting to 10 seconds.
    */
        public func withTimeout(timeout: Double) -> Builder {
            self.timeout = timeout
            return self
        }

        /**
        Build the Confidence instance.
        */
        public func build() -> Confidence {
            if debugLogger == nil {
                if loggerLevel != LoggerLevel.NONE {
                    debugLogger = DebugLoggerImpl(loggerLevel: loggerLevel, clientKey: clientSecret)
                    debugLogger?.logContext(action: "InitialContext", context: initialContext)
                }
            }
            let options = ConfidenceClientOptions(
                credentials: ConfidenceClientCredentials.clientSecret(secret: clientSecret),
                region: region,
                timeoutIntervalForRequest: timeout)
            let metadata = ConfidenceMetadata(
                name: sdkId,
                version: "1.4.4") // x-release-please-version
            let uploader = RemoteConfidenceClient(
                options: options,
                metadata: metadata,
                debugLogger: debugLogger
            )
            let httpClient = NetworkClient(
                baseUrl: BaseUrlMapper.from(region: options.region),
                timeoutIntervalForRequests: options.timeoutIntervalForRequest
            )
            let flagApplier = flagApplier ?? FlagApplierWithRetries(
                httpClient: httpClient,
                storage: DefaultStorage(filePath: "confidence.flags.apply"),
                options: options,
                metadata: metadata,
                debugLogger: debugLogger
            )
            let flagResolver = flagResolver ?? RemoteConfidenceResolveClient(
                options: options,
                applyOnResolve: false,
                metadata: metadata
            )
            let eventSenderEngine = EventSenderEngineImpl(
                clientSecret: clientSecret,
                uploader: uploader,
                storage: eventStorage,
                debugLogger: debugLogger
            )
            return Confidence(
                clientSecret: clientSecret,
                region: region,
                eventSenderEngine: eventSenderEngine,
                flagApplier: flagApplier,
                remoteFlagResolver: flagResolver,
                storage: storage ?? DefaultStorage(filePath: "confidence.flags.resolve"),
                context: initialContext,
                parent: nil,
                visitorId: visitorId,
                debugLogger: debugLogger
            )
        }
    }
}
// swiftlint:enable file_length
