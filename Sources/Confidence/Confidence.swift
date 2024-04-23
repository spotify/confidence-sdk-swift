import Foundation

public class Confidence: ConfidenceEventSender {
    private let parent: ConfidenceContextProvider?
    private var context: ConfidenceStruct
    public let clientSecret: String
    public var timeout: TimeInterval
    public var region: ConfidenceRegion
    let eventSenderEngine: EventSenderEngine
    public var initializationStrategy: InitializationStrategy
    private var removedContextKeys: Set<String> = Set()

    required init(
        clientSecret: String,
        timeout: TimeInterval,
        region: ConfidenceRegion,
        eventSenderEngine: EventSenderEngine,
        initializationStrategy: InitializationStrategy,
        context: ConfidenceStruct = [:],
        parent: ConfidenceEventSender? = nil
    ) {
        self.eventSenderEngine = eventSenderEngine
        self.clientSecret = clientSecret
        self.timeout = timeout
        self.region = region
        self.initializationStrategy = initializationStrategy
        self.context = context
        self.parent = parent
    }

    public func send(eventName: String, message: ConfidenceStruct) {
        eventSenderEngine.emit(eventName: eventName, message: message, context: getContext())
    }


    public func getContext() -> ConfidenceStruct {
        let parentContext = parent?.getContext() ?? [:]
        var reconciledCtx = parentContext.filter {
            !removedContextKeys.contains($0.key)
        }
        self.context.forEach { entry in
            reconciledCtx.updateValue(entry.value, forKey: entry.key)
        }
        return reconciledCtx
    }

    public func updateContextEntry(key: String, value: ConfidenceValue) {
        context[key] = value
    }

    public func removeContextEntry(key: String) {
        context.removeValue(forKey: key)
        removedContextKeys.insert(key)
    }

    public func withContext(_ context: ConfidenceStruct) -> Self {
        return Self.init(
            clientSecret: clientSecret,
            timeout: timeout,
            region: region,
            eventSenderEngine: eventSenderEngine,
            initializationStrategy: initializationStrategy,
            context: context,
            parent: self)
    }
}

extension Confidence {
    public class Builder {
        let clientSecret: String
        var timeout: TimeInterval = 10.0
        var region: ConfidenceRegion = .global
        var initializationStrategy: InitializationStrategy = .fetchAndActivate
        let eventStorage: EventStorage

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

        public func withInitializationstrategy(initializationStrategy: InitializationStrategy) -> Builder {
            self.initializationStrategy = initializationStrategy
            return self
        }

        public func build() -> Confidence {
            let uploader = RemoteConfidenceClient(
                options: ConfidenceClientOptions(
                    credentials: ConfidenceClientCredentials.clientSecret(secret: clientSecret),
                    timeout: timeout,
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
                timeout: timeout,
                region: region,
                eventSenderEngine: eventSenderEngine,
                initializationStrategy: initializationStrategy,
                context: [:],
                parent: nil
            )
        }
    }
}
