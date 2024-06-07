import Foundation
import Combine
import os

public class Confidence: ConfidenceEventSender {
    public let clientSecret: String
    public var region: ConfidenceRegion
    private let parent: ConfidenceContextProvider?
    private let eventSenderEngine: EventSenderEngine
    private let contextSubject = CurrentValueSubject<Confidence.ContextUpdateSignal, Never>(
        ContextUpdateSignal.init(context: [:], isProvider: false))
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
        self.contextSubject.value = ContextUpdateSignal.init(context: context, isProvider: false)
        self.parent = parent
        self.storage = storage
        self.flagApplier = flagApplier
        self.remoteFlagResolver = remoteFlagResolver
        if let visitorId {
            putContext(context: ["visitor_id": ConfidenceValue.init(string: visitorId)])
        }

        contextChanges().sink { [weak self] signal in
            guard let self = self else {
                return
            }
            self.currentFetchTask?.cancel()
            self.currentFetchTask = Task {
                do {
                    let context = self.getContext()
                    try await self.fetchAndActivate(isProvider: signal.isProvider)
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

    /**
    Fetches flag evaluations from backend and returns once the fetch is
    complete (regardless of success)
    Args:
    - isProvider: used in case of OpenFeature integration, do not override manually
    */
    public func fetchAndActivate(isProvider: Bool = false) async throws {
        try await internalFetch(isProvider: isProvider)
        try activate()
    }

    func internalFetch(isProvider: Bool) async throws {
        let context = getContext()
        let resolvedFlags = try await remoteFlagResolver.resolve(ctx: context, isProvider: isProvider)
        let resolution = FlagResolution(
            context: context,
            flags: resolvedFlags.resolvedValues,
            resolveToken: resolvedFlags.resolveToken ?? ""
        )
        try storage.save(data: resolution)
    }

    /**
    Start a network request to fetch flag evaluations from backend, returns immediately.
    In case of success storage cache will be updated for future sessions, but in-session cache remains unchanged.
    Args:
    - isProvider: used in case of OpenFeature integration, do not override manually
    */
    public func asyncFetch(isProvider: Bool = false) {
        Task {
            try await internalFetch(isProvider: isProvider)
        }
    }

    /**
    Read flag evaluation from local cache. Does not trigger a backend request.
    Args:
    - key: flag name followed by the path of the property you want to access (dot notation expected).
    e.g. "my-flag.my-property"
    - defaultValue: value return in case of errors, for example if the flag/property is not found
    - isProvider: used in case of OpenFeature integration, do not override manually
    */
    public func getEvaluation<T>(key: String, defaultValue: T, isProvider: Bool = false) throws -> Evaluation<T> {
        try self.cache.evaluate(
            flagName: key,
            defaultValue: defaultValue,
            context: getContext(),
            flagApplier: flagApplier,
            isProvider: isProvider
        )
    }

    public func getValue<T>(key: String, defaultValue: T) -> T {
        do {
            return try getEvaluation(key: key, defaultValue: defaultValue, isProvider: false).value
        } catch {
            return defaultValue
        }
    }

    func isStorageEmpty() -> Bool {
        return storage.isEmpty()
    }

    private func contextChanges() -> AnyPublisher<Confidence.ContextUpdateSignal, Never> {
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
        self.contextSubject.value.context.forEach { entry in
            reconciledCtx.updateValue(entry.value, forKey: entry.key)
        }
        return reconciledCtx
    }

    public func putContext(key: String, value: ConfidenceValue) {
        withLock { confidence in
            var map = confidence.contextSubject.value.context
            map[key] = value
            confidence.contextSubject.value = ContextUpdateSignal(context: map, isProvider: false)
        }
    }

    public func putContext(context: ConfidenceStruct) {
        withLock { confidence in
            var map = confidence.contextSubject.value.context
            for entry in context {
                map.updateValue(entry.value, forKey: entry.key)
            }
            confidence.contextSubject.value = ContextUpdateSignal(context: map, isProvider: false)
        }
    }

    /**
    Updates the context. This will trigger a new fetchAndActivate thus updating the cache mid-session.
    Args:
    - context: entries to be appended to the context
    - removeKeys: keys of the entries that are removed from the context (including parent entries)
    - isProvider: used in case of OpenFeature integration, do not override manually
    */
    public func putContext(context: ConfidenceStruct, removeKeys removedKeys: [String] = [], isProvider: Bool = false) {
        withLock { confidence in
            var map = confidence.contextSubject.value.context
            for removedKey in removedKeys {
                map.removeValue(forKey: removedKey)
            }
            for entry in context {
                map.updateValue(entry.value, forKey: entry.key)
            }
            confidence.contextSubject.value = ContextUpdateSignal.init(context: map, isProvider: isProvider)
        }
    }

    public func removeKey(key: String) {
        withLock { confidence in
            var map = confidence.contextSubject.value.context
            map.removeValue(forKey: key)
            confidence.contextSubject.value = ContextUpdateSignal(context: map, isProvider: false)
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

        var visitorId = VisitorUtil().getId()
        var initialContext: ConfidenceStruct = [:]

        /***
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

        /***
        Sets the region for the network request to the Confidence backend.
        The default is `global` and the requests are automatically routed to the closest server.
        */
        public func withRegion(region: ConfidenceRegion) -> Builder {
            self.region = region
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
                storage: eventStorage)
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

    private struct ContextUpdateSignal: Equatable, Hashable {
        let context: ConfidenceStruct
        let isProvider: Bool

        func hash(into hasher: inout Hasher) {
            hasher.combine(context.hash())
        }
    }
}
