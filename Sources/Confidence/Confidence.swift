import Foundation

public class Confidence: ConfidenceEventSender {
    private let parent: ConfidenceEventSender?
    private var localContext: ConfidenceStruct

    public var context: ConfidenceStruct {
        get {
            var mergedContext = parent?.context ?? [:]
            localContext.forEach { entry in
                mergedContext.updateValue(entry.value, forKey: entry.key)
            }
            return mergedContext
        }
        set {
            self.localContext = newValue
        }
    }
    public let clientSecret: String
    public var timeout: TimeInterval
    public var region: ConfidenceRegion
    public var initializationStrategy: InitializationStrategy

    required public init(
        clientSecret: String,
        timeout: TimeInterval,
        region: ConfidenceRegion,
        initializationStrategy: InitializationStrategy,
        context: ConfidenceStruct = [:],
        parent: ConfidenceEventSender? = nil
    ) {
        self.clientSecret = clientSecret
        self.timeout = timeout
        self.region = region
        self.initializationStrategy = initializationStrategy
        self.localContext = context
        self.parent = parent
    }

    // TODO: Implement actual event uploading to the backend
    public func send(definition: String, payload: ConfidenceStruct) {
        print("Sending: \"\(definition)\".\nMessage: \(payload)\nContext: \(context)")
    }

    public func updateContextEntry(key: String, value: ConfidenceValue) {
        localContext[key] = value
    }

    public func removeContextEntry(key: String) {
        localContext.removeValue(forKey: key)
    }

    public func clearContext() {
        localContext = [:]
    }

    public func withContext(_ context: ConfidenceStruct) -> Self {
        return Self.init(
            clientSecret: clientSecret,
            timeout: timeout,
            region: region,
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
