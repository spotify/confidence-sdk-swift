import Foundation

public enum BaseUrlMapper {
    /// Returns the base URL used for flag resolve and apply requests.
    /// A configured `resolveBaseUrl` takes precedence over the regional Confidence endpoint for flag resolves.
    static func from(options: ConfidenceClientOptions) -> String {
        if let resolveBaseUrl = options.resolveBaseUrl {
            return "\(resolveBaseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/v1/flags"
        }

        switch options.region {
        case .global:
            return "https://resolver.confidence.dev/v1/flags"
        case .europe:
            return "https://resolver.eu.confidence.dev/v1/flags"
        case .usa:
            return "https://resolver.us.confidence.dev/v1/flags"
        }
    }
}
