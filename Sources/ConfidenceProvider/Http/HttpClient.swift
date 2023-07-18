import Foundation

protocol HttpClient {
    func post<T: Decodable>(path: String, data: Codable, resultType: T.Type) throws -> HttpClientResponse<T>
}

final class NetworkClient: HttpClient {
    private let headers: [String: String]
    private let retry: Retry
    private let timeout: TimeInterval
    private let session: URLSession
    private let region: ConfidenceRegion

    private var baseUrl: String {
        let region = region.rawValue
        let domain = "confidence.dev"
        let resolveRoute = "/v1/flags"

        return "https://resolver.\(region).\(domain)\(resolveRoute)"
    }

    init(
        session: URLSession? = nil,
        region: ConfidenceRegion,
        defaultHeaders: [String: String] = [:],
        timeout: TimeInterval = 30.0,
        retry: Retry = .none
    ) {
        self.session =
            session
            ?? {
                let configuration = URLSessionConfiguration.default
                configuration.timeoutIntervalForRequest = timeout
                configuration.httpAdditionalHeaders = defaultHeaders

                return URLSession(configuration: configuration)
            }()

        self.headers = defaultHeaders
        self.retry = retry
        self.timeout = timeout
        self.region = region
    }

    func post<T: Decodable>(path: String, data: Codable, resultType: T.Type) throws -> HttpClientResponse<T> {
        guard let url = constructURL(base: baseUrl, path: path) else {
            throw ConfidenceError.internalError(message: "Could not create service url")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let jsonData = try encoder.encode(data)
        request.httpBody = jsonData

        let result = try perform(request: request, retry: self.retry)

        var response: HttpClientResponse<T> = HttpClientResponse(response: result.response)
        if let responseData = result.data {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if response.response.status == .ok {
                response.decodedData = try decoder.decode(resultType, from: responseData)
            } else {
                do {
                    response.decodedError = try decoder.decode(HttpError.self, from: responseData)
                } catch {
                    let message = String(data: responseData, encoding: String.Encoding.utf8)
                    response.decodedError = HttpError(
                        code: result.response.statusCode, message: message ?? "unknown", details: [])
                }
            }
        }

        return response
    }

    private func perform(request: URLRequest, retry: Retry) throws -> (response: HTTPURLResponse, data: Data?) {
        var retryWait: TimeInterval? = 0
        let retryHandler = retry.handler()

        var resultData: Data?
        var resultResponse: HTTPURLResponse?
        var resultError: Error?

        while true {
            let completeSemaphore = DispatchSemaphore(value: 0)
            // Would be nice to user the async API here instead, but then the whole chain would have
            // to be async, and we don't want to force users to async APIs
            var attemptRetry = false
            let task = self.session.dataTask(with: request) { data, response, error in
                defer { completeSemaphore.signal() }

                resultData = data
                resultError = error
                if (error as? URLError)?.code == .timedOut {
                    attemptRetry = true
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    resultError = HttpClientError.invalidResponse
                    return
                }

                resultResponse = httpResponse

                if httpResponse.status?.responseType == .serverError {
                    attemptRetry = true
                    return
                }
            }

            task.resume()
            _ = completeSemaphore.wait(timeout: .now() + .seconds(Int(self.timeout)))
            if !attemptRetry {
                break
            }

            retryWait = retryHandler.retryIn()
            guard let retryWait = retryWait else {
                break
            }

            Thread.sleep(forTimeInterval: retryWait)
        }

        if let resultError = resultError {
            throw resultError
        }

        guard let resultResponse = resultResponse else {
            throw HttpClientError.internalError
        }

        return (resultResponse, resultData)
    }

    // MARK: Private
    private func constructURL(base: String, path: String) -> URL? {
        let normalisedBase = base.hasSuffix("/") ? base : "\(base)/"
        let normalisedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path

        return URL(string: "\(normalisedBase)\(normalisedPath)")
    }
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
