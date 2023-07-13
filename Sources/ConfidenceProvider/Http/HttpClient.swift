import Foundation

protocol HttpClient {
    func post<T: Decodable>(path: String, data: Codable, completion: @escaping (HttpClientResponse<T>) -> Void) throws
    func post<T: Decodable>(path: String, data: Codable) async throws -> HttpClientResponse<T>
    func post<T: Decodable>(path: String, data: Codable) throws -> HttpClientResponse<T>
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

    /// An unsafe synchronous version of the async post function. It is not advised to use this unless absolutely necessary as it
    /// will block whichever thread you are on.
    func post<T>(path: String, data: Codable) throws -> HttpClientResponse<T> where T : Decodable {
        let semaphore = DispatchSemaphore(value: 0)
        let responseBox = Box<HttpClientResponse<T>>()
        Task {
            responseBox.value = try await post(path: path, data: data)
            semaphore.signal()
        }
        semaphore.wait()

        if let response = responseBox.value {
            return response
        }

        throw ConfidenceError.internalError(message: "No response received")
    }

    func post<T: Decodable>(path: String, data: Codable, completion: @escaping (HttpClientResponse<T>) -> Void) {
        Task {
            let result: HttpClientResponse<T> = try await post(path: path, data: data)
            completion(result)
        }
    }

    func post<T: Decodable>(path: String, data: Codable) async throws -> HttpClientResponse<T> {
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

        let result = try await perform(request: request, retry: self.retry)

        var response: HttpClientResponse<T> = HttpClientResponse(response: result.response)
        if let responseData = result.data {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if response.response.status == .ok {
                response.decodedData = try decoder.decode(T.self, from: responseData)
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

    private func perform(request: URLRequest, retry: Retry) async throws -> (response: HTTPURLResponse, data: Data?) {
        let retryHandler = retry.handler()
        let retryWait: TimeInterval? = retryHandler.retryIn()

        var resultData: Data?
        var resultResponse: HTTPURLResponse?

        do {
            let result: (Data, URLResponse) = try await self.session.data(for: request)

            guard let httpResponse = result.1 as? HTTPURLResponse else {
                throw HttpClientError.invalidResponse
            }

            if httpResponse.status?.responseType == .serverError {
                if let retryWait {
                    try await Task.sleep(nanoseconds: UInt64(retryWait * 1_000_000_000))
                    return try await perform(request: request, retry: retry)
                }
            }

            resultData = result.0
            resultResponse = httpResponse
        } catch {
            if (error as? URLError)?.code == .timedOut {
                if let retryWait {
                    try await Task.sleep(nanoseconds: UInt64(retryWait * 1_000_000_000))
                    return try await perform(request: request, retry: retry)
                }
            }

            throw error
        }

        guard let resultResponse else {
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
