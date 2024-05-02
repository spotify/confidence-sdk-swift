import Foundation
import Combine
import Common

public class Confidence: ConfidenceEventSender {
    public let clientSecret: String
    public var timeout: TimeInterval
    public var region: ConfidenceRegion
    private let parent: ConfidenceContextProvider?
    private let eventSenderEngine: EventSenderEngine
    private let contextFlow = CurrentValueSubject<ConfidenceStruct, Never>([:])
    private var removedContextKeys: Set<String> = Set()
    private let confidenceQueue = DispatchQueue(label: "com.confidence.queue")
    private let remoteFlagResolver: RemoteConfidenceResolveClient
    private let flagApplier: FlagApplier
    private var cache = FlagResolution.EMPTY
    private var storage: Storage

    required init(
        clientSecret: String,
        timeout: TimeInterval,
        region: ConfidenceRegion,
        eventSenderEngine: EventSenderEngine,
        flagApplier: FlagApplier,
        remoteFlagResolver: RemoteConfidenceResolveClient,
        storage: Storage,
        context: ConfidenceStruct = [:],
        parent: ConfidenceEventSender? = nil,
        visitorId: String? = nil
    ) {
        self.eventSenderEngine = eventSenderEngine
        self.clientSecret = clientSecret
        self.timeout = timeout
        self.region = region
        self.storage = storage
        self.contextFlow.value = context
        self.parent = parent
        self.storage = storage
        self.flagApplier = flagApplier
        self.remoteFlagResolver = remoteFlagResolver
        if let visitorId {
            putContext(context: ["visitorId": ConfidenceValue.init(string: visitorId)])
        }
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
        try storage.save(data: FlagResolution(context: context, flags: resolvedFlags.resolvedValues, resolveToken: resolvedFlags.resolveToken ?? ""))
    }

    public func asyncFetch() {
        Task {
            try await internalFetch()
        }
    }

    public func getFlag<T>(flagName: String, defaultValue: T) throws -> Evaluation<T> {
        try cache.evaluate(flagName: flagName, defaultValue: defaultValue, context: getContext(), flagApplier: flagApplier)
    }

    public func getValue<T>(flagName: String, defaultValue: T) throws -> T {
        try getFlag(flagName: flagName, defaultValue: defaultValue).value
    }

    func isStorageEmpty() -> Bool {
        return false
    }

    public func contextChanges() -> AnyPublisher<ConfidenceStruct, Never> {
        return contextFlow
            .dropFirst()
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    public func track(eventName: String, message: ConfidenceStruct) {
        eventSenderEngine.emit(eventName: eventName, message: message, context: getContext())
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
        self.contextFlow.value.forEach { entry in
            reconciledCtx.updateValue(entry.value, forKey: entry.key)
        }
        return reconciledCtx
    }

    public func putContext(key: String, value: ConfidenceValue) {
        withLock { confidence in
            var map = confidence.contextFlow.value
            map[key] = value
            confidence.contextFlow.value = map
        }
    }

    public func putContext(context: ConfidenceStruct) {
        withLock { confidence in
            var map = confidence.contextFlow.value
            for entry in context {
                map.updateValue(entry.value, forKey: entry.key)
            }
            confidence.contextFlow.value = map
        }
    }

    public func putContext(context: ConfidenceStruct, removedKeys: [String] = []) {
        withLock { confidence in
            var map = confidence.contextFlow.value
            for removedKey in removedKeys {
                map.removeValue(forKey: removedKey)
            }
            for entry in context {
                map.updateValue(entry.value, forKey: entry.key)
            }
            confidence.contextFlow.value = map
        }
    }

    public func removeContextEntry(key: String) {
        withLock { confidence in
            var map = confidence.contextFlow.value
            map.removeValue(forKey: key)
            confidence.contextFlow.value = map
            confidence.removedContextKeys.insert(key)
        }
    }

    public func withContext(_ context: ConfidenceStruct) -> Self {
        return Self.init(
            clientSecret: clientSecret,
            timeout: timeout,
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
        var timeout: TimeInterval = 10.0
        var region: ConfidenceRegion = .global
        let eventStorage: EventStorage
        var visitorId: String?

        public init(clientSecret: String) {
            self.clientSecret = clientSecret
            do {
                eventStorage = try EventStorageImpl()
            } catch {
                eventStorage = EventStorageInMemory()
            }
        }

        public func withTimeout(timeout: TimeInterval) -> Builder {
            self.timeout = timeout
            return self
        }


        public func withRegion(region: ConfidenceRegion) -> Builder {
            self.region = region
            return self
        }

        public func withVisitorId() -> Builder {
            self.visitorId = VisitorUtil().getId()
            return self
        }

        public func build() -> Confidence {
            let options = ConfidenceClientOptions(
                credentials: ConfidenceClientCredentials.clientSecret(secret: clientSecret),
                timeout: timeout,
                region: region)
            let metadata = ConfidenceMetadata(
                name: "SDK_ID_SWIFT_CONFIDENCE",
                version: "0.1.4") // x-release-please-version
            let uploader = RemoteConfidenceClient(
                options: options,
                metadata: metadata
            )
            let httpClient = NetworkClient(baseUrl: BaseUrlMapper.from(region: options.region))
            let flagApplier = FlagApplierWithRetries(httpClient: httpClient, storage: DefaultStorage(filePath: "confidence.flags.apply"), options: options, metadata: metadata)
            let flagResolver = RemoteConfidenceResolveClient(options: options, applyOnResolve: false, flagApplier: flagApplier, metadata: metadata)
            let eventSenderEngine = EventSenderEngineImpl(
                clientSecret: clientSecret,
                uploader: uploader,
                storage: eventStorage,
                flushPolicies: [SizeFlushPolicy(batchSize: 1)])
            return Confidence(
                clientSecret: clientSecret,
                timeout: timeout,
                region: region,
                eventSenderEngine: eventSenderEngine,
                flagApplier: flagApplier,
                remoteFlagResolver: flagResolver,
                storage: DefaultStorage(filePath: "confidence.flags.resolve"),
                context: [:],
                parent: nil,
                visitorId: visitorId
            )
        }
    }
}
