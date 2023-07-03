import Foundation
import OpenFeature

extension HTTPURLResponse {
    func mapStatusToError(error: HttpError?, flag: String = "unknown") -> Error {
        let defaultError = OpenFeatureError.generalError(
            message: "General error: \(error?.message ?? "Unknown error")")

        switch self.status {
        case .notFound:
            return OpenFeatureError.flagNotFoundError(key: flag)
        case .badRequest:
            return ConfidenceError.badRequest(message: error?.message ?? "")
        default:
            return defaultError
        }
    }
}
