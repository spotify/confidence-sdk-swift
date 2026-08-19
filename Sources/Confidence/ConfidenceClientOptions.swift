import Foundation

struct ConfidenceClientOptions {
    public var credentials: ConfidenceClientCredentials
    public var region: ConfidenceRegion
    public var resolveBaseUrl: String?
    public var initializationStrategy: InitializationStrategy
    public var timeoutIntervalForRequest: Double

    public init(
        credentials: ConfidenceClientCredentials,
        region: ConfidenceRegion? = nil,
        resolveBaseUrl: String? = nil,
        initializationStrategy: InitializationStrategy = .fetchAndActivate,
        timeoutIntervalForRequest: Double
    ) {
        self.credentials = credentials
        self.region = region ?? .global
        self.resolveBaseUrl = resolveBaseUrl
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
