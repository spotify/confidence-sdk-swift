import Foundation

public struct ConfidenceClientOptions {
    public var credentials: ConfidenceClientCredentials
    public var region: ConfidenceRegion
    public var initializationStrategy: InitializationStrategy

    public init(
        credentials: ConfidenceClientCredentials,
        region: ConfidenceRegion? = nil,
        initializationStrategy: InitializationStrategy = .fetchAndActivate
    ) {
        self.credentials = credentials
        self.region = region ?? .global
        self.initializationStrategy = initializationStrategy
    }
}

public enum ConfidenceClientCredentials {
    case clientSecret(secret: String)

    public func getSecret() -> String {
        switch self {
        case .clientSecret(let secret):
            return secret
        }
    }
}
