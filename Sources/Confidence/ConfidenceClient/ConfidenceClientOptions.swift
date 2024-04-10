import Foundation

public struct ConfidenceClientOptions {
    public var credentials: ConfidenceClientCredentials
    public var timeout: TimeInterval
    public var region: ConfidenceRegion

    public init(
        credentials: ConfidenceClientCredentials,
        timeout: TimeInterval? = nil,
        region: ConfidenceRegion? = nil
    ) {
        self.credentials = credentials
        self.timeout = timeout ?? 10.0
        self.region = region ?? .global
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
