import Foundation
import Confidence

public enum BaseUrlMapper {
    static func from(region: ConfidenceRegion) -> String {
        switch region {
        case .global:
            "https://resolver.confidence.dev/v1/flags"
        case .europe:
            "https://resolver.eu.confidence.dev/v1/flags"
        case .usa:
            "https://resolver.us.confidence.dev/v1/flags"
        }
    }
}
