import Foundation
import OpenFeature

public protocol ConfidenceProtocol {
    func providerBuilder() -> ConfidenceFeatureProvider.Builder
    func createEventSender() -> EventSender
}

// Should be a singleton
public class Confidence: ConfidenceProtocol {
    private let clientSecret: String
    // We should have the Provider as a singleton here

    public init(clientSecret: String) {
        self.clientSecret = clientSecret
    }
    
    public func providerBuilder() -> ConfidenceFeatureProvider.Builder {
        return ConfidenceFeatureProvider.Builder(
            credentials: ConfidenceClientCredentials.clientSecret(secret: clientSecret))
    }

    public func createEventSender() -> EventSender {
        return EventSenderClient(secret: clientSecret)
    }
}
