import Foundation
import Combine

public class Confidence: ConfidenceEventSender {
    public let clientSecret: String
    public var region: ConfidenceRegion
    private let parent: ConfidenceContextProvider?
    private let eventSenderEngine: EventSenderEngine
    private let contextSubject = CurrentValueSubject<ConfidenceStruct, Never>([:])
    private var removedContextKeys: Set<String> = Set()
    private let confidenceQueue = DispatchQueue(label: "com.confidence.queue")
    private let remoteFlagResolver: ConfidenceResolveClient
    private let flagApplier: FlagApplier
    private var cache = FlagResolution.EMPTY
    private var storage: Storage
    internal let contextReconciliatedChanges = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()
    private var currentFetchTask: Task<(), Never>?

    required init(
        clientSecret: String,
        region: ConfidenceRegion,
        eventSenderEngine: EventSenderEngine,
        flagApplier: FlagApplier,
        remoteFlagResolver: ConfidenceResolveClient,
        storage: Storage,
        context: ConfidenceStruct = [:],
        parent: ConfidenceEventSender? = nil,
        visitorId: String? = nil
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
                }
            }
        }
        .store(in: &cancellables)
    }

    public func activate() throws {
        let savedFlags = try storage.load(defaultValue: FlagResolution.EMPTY)
        self.cache = savedFlags
    }

    public func fetchAndActivate() async throws {
        try await internalFetch()
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
        try storage.save(data: resolution)
    }

    public func asyncFetch() {
        Task {
            try await internalFetch()
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

    public func track(eventName: String, message: ConfidenceStruct) {
        eventSenderEngine.emit(
            eventName: eventName,
            message: message,
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
                    self.track(eventName: event.name, message: event.message)
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
        }
    }

    public func putContext(context: ConfidenceStruct) {
        withLock { confidence in
            var map = confidence.contextSubject.value
            for entry in context {
                map.updateValue(entry.value, forKey: entry.key)
            }
            confidence.contextSubject.value = map
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
        }
    }

    public func removeKey(key: String) {
        withLock { confidence in
            var map = confidence.contextSubject.value
            map.removeValue(forKey: key)
            confidence.contextSubject.value = map
            confidence.removedContextKeys.insert(key)
        }
    }

    public func withContext(_ context: ConfidenceStruct) -> Self {
        return Self.init(
            clientSecret: clientSecret,
            region: region,
            eventSenderEngine: eventSenderEngine,
            flagApplier: flagApplier,
            remoteFlagResolver: remoteFlagResolver,
            storage: storage,
            context: context,
            parent: self)
    }
}

extension Confidence {
    public class Builder {
        let clientSecret: String
        internal var flagApplier: FlagApplier?
        internal var storage: Storage?
        internal let eventStorage: EventStorage
        internal var flagResolver: ConfidenceResolveClient?
        var region: ConfidenceRegion = .global

        var visitorId: String?
        var initialContext: ConfidenceStruct = [:]

        /**
        Initializes the builder with the given credentails.
        */
        public init(clientSecret: String) {
            self.clientSecret = clientSecret
            do {
                eventStorage = try EventStorageImpl()
            } catch {
                eventStorage = EventStorageInMemory()
            }
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

        /**
        The SDK attaches a unique identifier to the Context, which is persisted across
        restarts of the App but re-generated on every new install
        */
        public func withVisitorId() -> Builder {
            self.visitorId = VisitorUtil().getId()
            return self
        }

        public func build() -> Confidence {
            let options = ConfidenceClientOptions(
                credentials: ConfidenceClientCredentials.clientSecret(secret: clientSecret),
                region: region)
            let metadata = ConfidenceMetadata(
                name: "SDK_ID_SWIFT_CONFIDENCE",
                version: "0.1.4") // x-release-please-version
            let uploader = RemoteConfidenceClient(
                options: options,
                metadata: metadata
            )
            let httpClient = NetworkClient(baseUrl: BaseUrlMapper.from(region: options.region))
            let flagApplier = flagApplier ?? FlagApplierWithRetries(
                httpClient: httpClient,
                storage: DefaultStorage(filePath: "confidence.flags.apply"),
                options: options,
                metadata: metadata
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
                flushPolicies: [SizeFlushPolicy(batchSize: 1)])
            return Confidence(
                clientSecret: clientSecret,
                region: region,
                eventSenderEngine: eventSenderEngine,
                flagApplier: flagApplier,
                remoteFlagResolver: flagResolver,
                storage: storage ?? DefaultStorage(filePath: "confidence.flags.resolve"),
                context: initialContext,
                parent: nil,
                visitorId: visitorId
            )
        }
    }
}
