import Foundation

public class Confidence: ConfidenceEventSender {
    private let parent: ConfidenceContextProvider?
    private var context: ConfidenceStruct
    public let clientSecret: String
    public var timeout: TimeInterval
    public var region: ConfidenceRegion
    public var initializationStrategy: InitializationStrategy
    private var removedContextKeys: Set<String> = Set()
    private var client: ConfidenceClient

    required public init(
        clientSecret: String,
        timeout: TimeInterval,
        region: ConfidenceRegion,
        initializationStrategy: InitializationStrategy,
        context: ConfidenceStruct = [:],
        client: ConfidenceClient,
        parent: ConfidenceEventSender? = nil
    ) {
        self.clientSecret = clientSecret
        self.timeout = timeout
        self.region = region
        self.initializationStrategy = initializationStrategy
        self.context = context
        self.client = client
        self.parent = parent
    }

    // TODO: Implement actual event uploading to the backend
    public func send(definition: String, payload: ConfidenceStruct) {
        print("Sending: \"\(definition)\".\nMessage: \(payload)\nContext: \(context)")
        Task {
            try? await client.send(definition: definition, payload: payload)
        }
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
            initializationStrategy: initializationStrategy,
            context: context,
            client: client,
            parent: self)
    }
}

extension Confidence {
    public class Builder {
        let clientSecret: String
        var timeout: TimeInterval = 10.0
        var region: ConfidenceRegion = .global
        var initializationStrategy: InitializationStrategy = .fetchAndActivate

        public init(clientSecret: String) {
            self.clientSecret = clientSecret
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
            return Confidence(
                clientSecret: clientSecret,
                timeout: timeout,
                region: region,
                initializationStrategy: initializationStrategy,
                client: RemoteConfidenceClient(
                    options: ConfidenceClientOptions(credentials: ConfidenceClientCredentials.clientSecret(secret: clientSecret), region: region),
                    metadata: ConfidenceMetadata(
                        name: "SDK_ID_SWIFT_CONFIDENCE",
                        version: "0.1.4") // x-release-please-version
                )
            )
        }
    }
}
