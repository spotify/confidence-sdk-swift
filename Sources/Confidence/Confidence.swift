import Foundation

public class Confidence: ConfidenceEventSender {
    public var context: ConfidenceStruct
    public let clientSecret: String
    public var timeout: TimeInterval
    public var region: ConfidenceRegion
    public var initializationStrategy: InitializationStrategy

    init(
        clientSecret: String,
        timeout: TimeInterval,
        region: ConfidenceRegion,
        initializationStrategy: InitializationStrategy
    ) {
        self.context = [:]
        self.clientSecret = clientSecret
        self.timeout = timeout
        self.region = region
        self.initializationStrategy = initializationStrategy
    }

    // TODO: Implement actual event uploading to the backend
    public func send(definition: String, payload: ConfidenceStruct) {
        print("Sending \(definition) - Targeting key: \(payload)")
    }

    public func updateContextEntry(key: String, value: ConfidenceValue) {
        context[key] = value
    }

    public func removeContextEntry(key: String) {
        context.removeValue(forKey: key)
    }

    public func clearContext() {
        context = [:]
    }

    // TODO: Implement creation of child instances
    public func withContext(_ context: ConfidenceStruct) -> Self {
        return self
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
                initializationStrategy: initializationStrategy
            )
        }
    }
}