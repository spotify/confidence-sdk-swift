import Foundation

typealias HttpClientResult<T> = Result<HttpClientResponse<T>, Error>

protocol HttpClient {
    func post<T: Decodable>(path: String, data: Encodable) async throws -> HttpClientResult<T>
}

struct HttpClientResponse<T> {
    var decodedData: T?
    var decodedError: HttpError?
    var response: HTTPURLResponse
}

struct HttpError: Codable {
    var code: Int
    var message: String
    var details: [String]
}

enum HttpClientError: Error {
    case invalidResponse
    case internalError
}

extension HTTPURLResponse {
    func mapStatusToError(error: HttpError?, flag: String = "unknown") -> Error {
        let defaultError = ConfidenceError.internalError(
            message: "General error: \(error?.message ?? "Unknown error")")

        switch self.status {
        case .notFound:
            return ConfidenceError.badRequest(message: flag) // TODO
        case .badRequest:
            return ConfidenceError.badRequest(message: error?.message ?? "")
        default:
            return defaultError
        }
    }
}
