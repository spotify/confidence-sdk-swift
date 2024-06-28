import Foundation
import Combine
import os

public class Confidence: ConfidenceEventSender {
    private let clientSecret: String
    private var region: ConfidenceRegion
    private let parent: ConfidenceContextProvider?
    private let eventSenderEngine: EventSenderEngine
    private let contextSubject = CurrentValueSubject<ConfidenceStruct, Never>([:])
    private var removedContextKeys: Set<String> = Set()
    private let confidenceQueue = DispatchQueue(label: "com.confidence.queue")
    private let flagApplier: FlagApplier
    private var cache = FlagResolution.EMPTY
    private var storage: Storage
    private var cancellables = Set<AnyCancellable>()
    private var currentFetchTask: Task<(), Never>?
    private let debugLogger: DebugLogger?

    // Internal for testing
    internal let remoteFlagResolver: ConfidenceResolveClient
    internal let contextReconciliatedChanges = PassthroughSubject<String, Never>()

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
        self.contextSubject.value = context
        self.parent = parent
        self.storage = storage
        self.flagApplier = flagApplier
        self.remoteFlagResolver = remoteFlagResolver
        self.debugLogger = debugLogger
        if let visitorId {
            putContext(context: ["visitor_id": ConfidenceValue.init(string: visitorId)])
        }

        contextChanges().sink { [weak self] context in
            guard let self = self else {
                return
            }
            self.currentFetchTask?.cancel()
            self.currentFetchTask = Task {
                do {
                    let context = self.getContext()
                    try await self.fetchAndActivate()
                    self.contextReconciliatedChanges.send(context.hash())
                } catch {
                    debugLogger?.logMessage(
                        message: "\(error)",
                        isWarning: true
                    )
                }
            }
        }
        .store(in: &cancellables)
    }
    /**
    Activating the cache means that the flag data on disk is loaded into memory, so consumers can access flag values.
    Errors can be thrown if something goes wrong access data on disk.
    */
    public func activate() throws {
        let savedFlags = try storage.load(defaultValue: FlagResolution.EMPTY)
        self.cache = savedFlags
        debugLogger?.logFlags(action: "Activate", flag: "")
    }

    /**
    Fetches latest flag evaluations and store them on disk. Regardless of the fetch outcome (success or failure), this
    function activates the cache after the fetch.
    Activating the cache means that the flag data on disk is loaded into memory, so consumers can access flag values.
    Fetching is best-effort, so no error is propagated. Errors can still be thrown if something goes wrong access data on disk.
    */
    public func fetchAndActivate() async throws {
        do {
            try await internalFetch()
        } catch {
            debugLogger?.logMessage(
                message: "\(error)",
                isWarning: true
            )
        }
        try activate()
    }

    func internalFetch() async throws {
        let context = getContext()
        let resolvedFlags = try await remoteFlagResolver.resolve(ctx: context)
        let resolution = FlagResolution(
            context: context,
            flags: resolvedFlags.resolvedValues,
            resolveToken: resolvedFlags.resolveToken ?? ""
        )
        debugLogger?.logFlags(action: "Fetch", flag: "")
        try storage.save(data: resolution)
    }

    /**
    Fetches latest flag evaluations and store them on disk. Note that "activate" must be called for this data to be
    made available in the app session.
    */
    public func asyncFetch() {
        Task {
            do {
                try await internalFetch()
            } catch {
                debugLogger?.logMessage(
                    message: "\(error )",
                    isWarning: true
                )
            }
        }
    }

    public func getEvaluation<T>(key: String, defaultValue: T) throws -> Evaluation<T> {
        try self.cache.evaluate(
            flagName: key,
            defaultValue: defaultValue,
            context: getContext(),
            flagApplier: flagApplier
        )
    }

    public func getValue<T>(key: String, defaultValue: T) -> T {
        do {
            return try getEvaluation(key: key, defaultValue: defaultValue).value
        } catch {
            return defaultValue
        }
    }

    func isStorageEmpty() -> Bool {
        return storage.isEmpty()
    }

    public func contextChanges() -> AnyPublisher<ConfidenceStruct, Never> {
        return contextSubject
            .dropFirst()
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    public func track(eventName: String, data: ConfidenceStruct) throws {
        try eventSenderEngine.emit(
            eventName: eventName,
            data: data,
            context: getContext()
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
                    guard let self = self else {
                        return
                    }
                    self.putContext(context: context)
                }
                .store(in: &cancellables)
        }
    }

    public func flush() {
        eventSenderEngine.flush()
    }

    private func withLock(callback: @escaping (Confidence) -> Void) {
        confidenceQueue.sync {  [weak self] in
            guard let self = self else {
                return
            }
            callback(self)
        }
    }

    public func getContext() -> ConfidenceStruct {
        let parentContext = parent?.getContext() ?? [:]
        var reconciledCtx = parentContext.filter {
            !removedContextKeys.contains($0.key)
        }
        self.contextSubject.value.forEach { entry in
            reconciledCtx.updateValue(entry.value, forKey: entry.key)
        }
        return reconciledCtx
    }

    public func putContext(key: String, value: ConfidenceValue) {
        withLock { confidence in
            var map = confidence.contextSubject.value
            map[key] = value
            confidence.contextSubject.value = map
            confidence.debugLogger?.logContext(action: "PutContext", context: confidence.contextSubject.value)
        }
    }

    public func putContext(context: ConfidenceStruct) {
        withLock { confidence in
            var map = confidence.contextSubject.value
            for entry in context {
                map.updateValue(entry.value, forKey: entry.key)
            }
            confidence.contextSubject.value = map
            confidence.debugLogger?.logContext(action: "PutContext", context: confidence.contextSubject.value)
        }
    }

    public func putContext(context: ConfidenceStruct, removeKeys removedKeys: [String] = []) {
        withLock { confidence in
            var map = confidence.contextSubject.value
            for removedKey in removedKeys {
                map.removeValue(forKey: removedKey)
            }
            for entry in context {
                map.updateValue(entry.value, forKey: entry.key)
            }
            confidence.contextSubject.value = map
            confidence.debugLogger?.logContext(action: "PutContext", context: confidence.contextSubject.value)
        }
    }

    public func removeKey(key: String) {
        withLock { confidence in
            var map = confidence.contextSubject.value
            map.removeValue(forKey: key)
            confidence.contextSubject.value = map
            confidence.removedContextKeys.insert(key)
            confidence.debugLogger?.logContext(action: "RemoveContext", context: confidence.contextSubject.value)
        }
    }

    /**
    Sets the initial Context.
    */
    public func withContext(_ context: ConfidenceStruct) -> Self {
        return Self.init(
            clientSecret: clientSecret,
            region: region,
            eventSenderEngine: eventSenderEngine,
            flagApplier: flagApplier,
            remoteFlagResolver: remoteFlagResolver,
            storage: storage,
            context: context,
            parent: self,
            debugLogger: debugLogger)
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
        internal var metadata: ConfidenceMetadata?
        internal var initialContext: ConfidenceStruct = [:]

        // Injectable for testing
        internal var flagApplier: FlagApplier?
        internal var storage: Storage?
        internal var flagResolver: ConfidenceResolveClient?

        /**
        Initializes the builder with the given credentails.
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

        public func withContext(initialContext: ConfidenceStruct) -> Builder {
            self.initialContext = initialContext
            return self
        }

        /**
        Sets the region for the network request to the Confidence backend.
        The default is `global` and the requests are automatically routed to the closest server.
        */
        public func withRegion(region: ConfidenceRegion) -> Builder {
            self.region = region
            return self
        }

        public func build() -> Confidence {
            var debugLogger: DebugLogger?
            if loggerLevel != LoggerLevel.NONE {
                debugLogger = DebugLoggerImpl(loggerLevel: loggerLevel)
                debugLogger?.logContext(action: "InitialContext", context: initialContext)
            } else {
                debugLogger = nil
            }
            let options = ConfidenceClientOptions(
                credentials: ConfidenceClientCredentials.clientSecret(secret: clientSecret),
                region: region)
            let metadata = ConfidenceMetadata(
                name: sdkId,
                version: "0.2.3") // x-release-please-version
            let uploader = RemoteConfidenceClient(
                options: options,
                metadata: metadata
            )
            let httpClient = NetworkClient(baseUrl: BaseUrlMapper.from(region: options.region))
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
