import Foundation

public enum BaseUrlMapper {
    static func from(region: ConfidenceRegion) -> String {
        switch region {
        case .global:
            return "https://resolver.confidence.dev/v1/flags"
        case .europe:
            return "https://resolver.eu.confidence.dev/v1/flags"
        case .usa:
            return "https://resolver.us.confidence.dev/v1/flags"
        }
    }
}
