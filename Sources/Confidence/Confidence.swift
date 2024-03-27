import Foundation

public class Confidence: ConfidenceEventSender {
    public var context: [String : String]
    public let clientSecret: String
    public let options: ConfidenceClientOptions

    init(clientSecret: String,
         options: ConfidenceClientOptions) {
        self.clientSecret = clientSecret
        self.options = options
        self.context = [:]
    }

    public func send(eventName: String) {
        print("Sending \(eventName)")
    }

    public func updateContextEntry(key: String, value: String) {
        context[key] = value
    }

    public func removeContextEntry(key: String) {
        context.removeValue(forKey: key)
    }

    public func clearContext() {
        context = [:]
    }

    public func withContext(_ context: [String : String]) -> Self {
        // TODO
        return self
    }
}

extension Confidence {
    public struct Builder {
        let clientSecret: String
        var options: ConfidenceClientOptions

        public init(clientSecret: String) {
            self.clientSecret = clientSecret
            self.options = ConfidenceClientOptions(credentials: ConfidenceClientCredentials.clientSecret(secret: (clientSecret)))
        }

        init(clientSecret: String, options: ConfidenceClientOptions) {
            self.clientSecret = clientSecret
            self.options = options
        }

        public func withOptions(options: ConfidenceClientOptions) -> Builder {
            return Builder(
                clientSecret: clientSecret,
                options: options
            )
        }

        public func build() -> Confidence {
            return Confidence(clientSecret: clientSecret, options: ConfidenceClientOptions())
        }
    }
}
