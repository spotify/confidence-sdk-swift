import Foundation

typealias HttpClientResult<T> = Result<HttpClientResponse<T>, Error>

internal protocol HttpClient {
    func post<T: Decodable>(path: String, data: Encodable) async throws -> HttpClientResult<T>
}

struct HttpClientResponse<T> {
    public init(decodedData: T? = nil, decodedError: HttpError? = nil, response: HTTPURLResponse) {
        self.decodedData = decodedData
        self.decodedError = decodedError
        self.response = response
    }
    public var decodedData: T?
    public var decodedError: HttpError?
    public var response: HTTPURLResponse
}

struct HttpError: Codable {
    public init(code: Int, message: String, details: [String]) {
        self.code = code
        self.message = message
        self.details = details
    }
    public var code: Int
    public var message: String
    public var details: [String]
}

enum HttpClientError: Error {
    case invalidResponse
    case internalError
}

extension HTTPURLResponse {
    func mapStatusToError(error: HttpError?) -> ConfidenceError {
        let defaultError = ConfidenceError.internalError(
            message: "General error: \(error?.message ?? "Unknown error")")

        switch self.status {
        case .notFound, .badRequest:
            return ConfidenceError.badRequest(message: error?.message)
        default:
            return defaultError
        }
    }
}
