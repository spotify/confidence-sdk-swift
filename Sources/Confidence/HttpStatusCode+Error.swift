import Foundation

extension HTTPURLResponse {
    func mapStatusToError(error: HttpError?, flag: String = "unknown") -> Error {
        let defaultError = ConfidenceError.internalError(
            message: "General error: \(error?.message ?? "Unknown error")")

        switch self.status {
        case .notFound:
            return ConfidenceError.flagNotFoundError(key: flag)
        case .badRequest:
            return ConfidenceError.badRequest(message: error?.message)
        default:
            return defaultError
        }
    }
}
