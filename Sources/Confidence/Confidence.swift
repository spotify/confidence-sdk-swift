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
    private let telemetry: Telemetry

    // Synchronization and task management resources
    private var cancellables = Set<AnyCancellable>()
    private let cacheQueue = DispatchQueue(label: "com.confidence.queue.cache")
    private var taskManager = TaskManager()

    // Internal for testing
    internal let remoteFlagResolver: ConfidenceResolveClient

    public static let sdkId: String = "SDK_ID_SWIFT_CONFIDENCE"

    public func setTelemetryLibraryOpenFeature() {
        telemetry.library = .openFeature
    }

    required init(
        clientSecret: String,
        region: ConfidenceRegion,
        eventSenderEngine: EventSenderEngine,
        flagApplier: FlagApplier,
        remoteFlagResolver: ConfidenceResolveClient,
        storage: Storage,
        telemetry: Telemetry,
        context: ConfidenceStruct = [:],
        parent: ConfidenceEventSender? = nil,
        visitorId: String? = nil,
        debugLogger: DebugLogger?
    ) {
        self.eventSenderEngine = eventSenderEngine
        self.clientSecret = clientSecret
        self.region = region
        self.storage = storage
        self.telemetry = telemetry
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
        try Task.checkCancellation()
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
        let evaluation: Evaluation<T> = cacheQueue.sync {  [weak self] in
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
        telemetry.trackEvaluation(reason: evaluation.reason, errorCode: evaluation.errorCode)
        return evaluation
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
        _ = await scheduleContextChange(context: [key: value], removedKeys: [], logAction: "PutContext")
    }

    public func putContextAndWait(context: ConfidenceStruct, removedKeys: [String] = []) async {
        _ = await scheduleContextChange(context: context, removedKeys: removedKeys, logAction: "PutContext")
    }

    public func putContextAndWait(context: ConfidenceStruct) async {
        _ = await scheduleContextChange(context: context, removedKeys: [], logAction: "PutContext")
    }

    public func removeContextAndWait(key: String) async {
        _ = await scheduleContextChange(context: [:], removedKeys: [key], logAction: "RemoveContext")
    }

    /**
    Applies context and fetches flags for it.
    Returns success only when the fetch is stored and activated for this call; does not throw.
    If a later context change supersedes this one, returns `CancellationError`.
    */
    public func reconcileContext(
        context: ConfidenceStruct,
        removedKeys: [String] = []
    ) async -> Result<Void, Error> {
        await scheduleOwnedContextChange(
            context: context,
            removedKeys: removedKeys,
            logAction: "PutContext"
        )
    }

    /**
    Applies context and loads flags according to `strategy`.
    If a later context change supersedes this call, returns `CancellationError`.
    */
    public func applyContext(
        context: ConfidenceStruct,
        strategy: InitializationStrategy,
        removedKeys: [String] = []
    ) async -> Result<Void, Error> {
        switch strategy {
        case .fetchAndActivate:
            return await scheduleOwnedContextChange(
                context: context,
                removedKeys: removedKeys,
                logAction: "PutContext",
                ignoreFetchFailure: true
            )
        case .activateAndFetchAsync:
            return await activateThenPrefetch(context: context, removedKeys: removedKeys)
        }
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
        startContextChange(context: [key: value], removedKeys: [], logAction: "PutContext")
    }

    public func putContext(context: ConfidenceStruct) {
        startContextChange(context: context, removedKeys: [], logAction: "PutContext")
    }

    public func putContext(context: ConfidenceStruct, removeKeys removedKeys: [String] = []) {
        startContextChange(context: context, removedKeys: removedKeys, logAction: "PutContext")
    }

    public func removeContext(key: String) {
        startContextChange(context: [:], removedKeys: [key], logAction: "RemoveContext")
    }

    public func putContext(context: ConfidenceStruct, removedKeys: [String]) {
        startContextChange(context: context, removedKeys: removedKeys, logAction: "RemoveContext")
    }

    /**
    Ensures all the already-started context changes prior to this function have been reconciliated
    */
    public func awaitReconciliation() async {
        await taskManager.awaitReconciliation()
    }

    private func scheduleContextChange(
        context: ConfidenceStruct,
        removedKeys: [String],
        logAction: String
    ) async -> Result<Void, Error> {
        startContextChange(context: context, removedKeys: removedKeys, logAction: logAction)
        return await taskManager.awaitReconciliation()
    }

    private func scheduleOwnedContextChange(
        context: ConfidenceStruct,
        removedKeys: [String],
        logAction: String,
        ignoreFetchFailure: Bool = false
    ) async -> Result<Void, Error> {
        let task = startContextChange(
            context: context,
            removedKeys: removedKeys,
            logAction: logAction,
            ignoreFetchFailure: ignoreFetchFailure
        )
        return await ownedResult(of: task)
    }

    @discardableResult
    private func startContextChange(
        context: ConfidenceStruct,
        removedKeys: [String],
        logAction: String,
        ignoreFetchFailure: Bool = false
    ) -> Task<Result<Void, Error>, Never> {
        taskManager.start(applying: {
            _ = self.contextManager.updateContext(withValues: context, removedKeys: removedKeys)
        }, operation: {
            await self.performFetchAndActivate(
                logAction: logAction,
                ignoreFetchFailure: ignoreFetchFailure
            )
        })
    }

    private func ownedResult(
        of task: Task<Result<Void, Error>, Never>
    ) async -> Result<Void, Error> {
        let result = await task.value
        if task.isCancelled || !taskManager.isCurrent(task) {
            return .failure(CancellationError())
        }
        return result
    }

    private func activateThenPrefetch(
        context: ConfidenceStruct,
        removedKeys: [String]
    ) async -> Result<Void, Error> {
        await withCheckedContinuation { continuation in
            let resume = OnceResume(continuation)
            _ = taskManager.start(applying: {
                _ = self.contextManager.updateContext(withValues: context, removedKeys: removedKeys)
            }, operation: {
                if Task.isCancelled {
                    resume.finish(.failure(CancellationError()))
                    return .failure(CancellationError())
                }
                do {
                    try self.activate()
                } catch {
                    resume.finish(.failure(error))
                    return .failure(error)
                }
                resume.finish(.success(()))
                if Task.isCancelled {
                    return .failure(CancellationError())
                }
                do {
                    try await self.internalFetch()
                    return .success(())
                } catch {
                    if self.isCancellation(error) {
                        return .failure(CancellationError())
                    }
                    self.debugLogger?.logMessage(
                        message: "\(error)",
                        isWarning: true
                    )
                    return .failure(error)
                }
            })
        }
    }

    private func performFetchAndActivate(
        logAction: String,
        ignoreFetchFailure: Bool
    ) async -> Result<Void, Error> {
        if Task.isCancelled {
            return .failure(CancellationError())
        }

        do {
            do {
                try await internalFetch()
            } catch {
                if isCancellation(error) {
                    throw CancellationError()
                }
                if !ignoreFetchFailure {
                    throw error
                }
                debugLogger?.logMessage(
                    message: "\(error)",
                    isWarning: true
                )
            }
            try Task.checkCancellation()
            try activate()
            debugLogger?.logContext(action: logAction, context: getContext())
            return .success(())
        } catch {
            if isCancellation(error) {
                return .failure(CancellationError())
            }
            debugLogger?.logMessage(
                message: "Error when putting context: \(error)",
                isWarning: true)
            try? activate()
            return .failure(error)
        }
    }

    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }
        if Task.isCancelled {
            return true
        }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    public func withContext(_ context: ConfidenceStruct) -> ConfidenceEventSender {
        return Self.init(
            clientSecret: clientSecret,
            region: region,
            eventSenderEngine: eventSenderEngine,
            flagApplier: flagApplier,
            remoteFlagResolver: remoteFlagResolver,
            storage: storage,
            telemetry: telemetry,
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

private final class OnceResume<T> {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Never>?

    init(_ continuation: CheckedContinuation<T, Never>) {
        self.continuation = continuation
    }

    func finish(_ value: T) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(returning: value)
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
            let telemetry = Telemetry(
                sdkId: sdkId,
                library: .confidence,
                libraryVersion: "1.5.0", // x-release-please-version
                debugLogger: debugLogger)
            let uploader = RemoteConfidenceClient(
                options: options,
                telemetry: telemetry,
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
                telemetry: telemetry,
                debugLogger: debugLogger
            )
            let flagResolver = flagResolver ?? RemoteConfidenceResolveClient(
                options: options,
                applyOnResolve: false,
                telemetry: telemetry
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
                telemetry: telemetry,
                context: initialContext,
                parent: nil,
                visitorId: visitorId,
                debugLogger: debugLogger
            )
        }
    }
}
// swiftlint:enable file_length
