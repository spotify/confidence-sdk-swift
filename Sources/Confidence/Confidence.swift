import Foundation
import Combine

public class Confidence: ConfidenceEventSender {
    public let clientSecret: String
    public var region: ConfidenceRegion
    public var initializationStrategy: InitializationStrategy
    private let parent: ConfidenceContextProvider?
    private let eventSenderEngine: EventSenderEngine
    private let contextFlow = CurrentValueSubject<ConfidenceStruct, Never>([:])
    private var removedContextKeys: Set<String> = Set()
    private let confidenceQueue = DispatchQueue(label: "com.confidence.queue")

    /// Internal, the hosting app should use Confidence.Builder instead
    required init(
        clientSecret: String,
        region: ConfidenceRegion,
        eventSenderEngine: EventSenderEngine,
        initializationStrategy: InitializationStrategy,
        context: ConfidenceStruct = [:],
        parent: ConfidenceEventSender? = nil,
        visitorId: String? = nil
    ) {
        self.eventSenderEngine = eventSenderEngine
        self.clientSecret = clientSecret
        self.region = region
        self.initializationStrategy = initializationStrategy
        self.contextFlow.value = context
        self.parent = parent
        if let visitorId {
            putContext(context: ["visitor_id": ConfidenceValue.init(string: visitorId)])
        }
    }

    public func track(eventName: String, message: ConfidenceStruct) {
        eventSenderEngine.emit(eventName: eventName, message: message, context: getContext())
    }

    /// Allows to observe changes in the Context, not meant to be used directly by the hosting app
    public func contextChanges() -> AnyPublisher<ConfidenceStruct, Never> {
        return contextFlow
            .dropFirst()
            .removeDuplicates()
            .eraseToAnyPublisher()
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

    private func putContext(context: ConfidenceStruct) {
        withLock { confidence in
            var map = confidence.contextFlow.value
            for entry in context {
                map.updateValue(entry.value, forKey: entry.key)
            }
            confidence.contextFlow.value = map
        }
    }

    public func putContext(context: ConfidenceStruct, removeKeys: [String] = []) {
        withLock { confidence in
            var map = confidence.contextFlow.value
            for removedKey in removeKeys {
                map.removeValue(forKey: removedKey)
            }
            for entry in context {
                map.updateValue(entry.value, forKey: entry.key)
            }
            confidence.contextFlow.value = map
        }
    }

    public func removeKey(key: String) {
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
            region: region,
            eventSenderEngine: eventSenderEngine,
            initializationStrategy: initializationStrategy,
            context: context,
            parent: self)
    }
}

// MARK: Builder

extension Confidence {
    public class Builder {
        let clientSecret: String
        var region: ConfidenceRegion = .global
        var initializationStrategy: InitializationStrategy = .fetchAndActivate
        let eventStorage: EventStorage
        var visitorId: String?

        /// Initializes the builder with the given credentails.
        public init(clientSecret: String) {
            self.clientSecret = clientSecret
            do {
                eventStorage = try EventStorageImpl()
            } catch {
                eventStorage = EventStorageInMemory()
            }
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
        Flag resolve configuration related to how to refresh flags at startup
        */
        public func withInitializationstrategy(initializationStrategy: InitializationStrategy) -> Builder {
            self.initializationStrategy = initializationStrategy
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
            let uploader = RemoteConfidenceClient(
                options: ConfidenceClientOptions(
                    credentials: ConfidenceClientCredentials.clientSecret(secret: clientSecret),
                    region: region),
                metadata: ConfidenceMetadata(
                    name: "SDK_ID_SWIFT_CONFIDENCE",
                    version: "0.1.4") // x-release-please-version
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
                initializationStrategy: initializationStrategy,
                context: [:],
                parent: nil,
                visitorId: visitorId
            )
        }
    }
}
