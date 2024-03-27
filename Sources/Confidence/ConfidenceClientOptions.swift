import Foundation

public struct ConfidenceClientOptions {
    public var credentials: ConfidenceClientCredentials // DEPRECATED
    public var timeout: TimeInterval
    public var region: ConfidenceRegion
    public var initializationStrategy: InitializationStrategy

    public init(
        credentials: ConfidenceClientCredentials? = nil,
        timeout: TimeInterval? = nil,
        region: ConfidenceRegion? = nil,
        initializationStrategy: InitializationStrategy = .fetchAndActivate
    ) {
        self.credentials = credentials ?? ConfidenceClientCredentials.clientSecret(secret: "")
        self.timeout = timeout ?? 10.0
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

public enum ConfidenceRegion {
    case global
    case europe
    case usa
}

public enum InitializationStrategy {
    case fetchAndActivate, activateAndFetchAsync
}
