import Foundation

struct ConfidenceClientOptions {
    public var credentials: ConfidenceClientCredentials
    public var region: ConfidenceRegion
    public var initializationStrategy: InitializationStrategy
    public var timeoutIntervalForRequest: Double

    public init(
        credentials: ConfidenceClientCredentials,
        region: ConfidenceRegion? = nil,
        initializationStrategy: InitializationStrategy = .fetchAndActivate,
        timeoutIntervalForRequest: Double
    ) {
        self.credentials = credentials
        self.region = region ?? .global
        self.initializationStrategy = initializationStrategy
        self.timeoutIntervalForRequest = timeoutIntervalForRequest
    }
}

enum ConfidenceClientCredentials {
    case clientSecret(secret: String)

    public func getSecret() -> String {
        switch self {
        case .clientSecret(let secret):
            return secret
        }
    }
}
