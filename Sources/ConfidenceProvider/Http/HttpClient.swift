import Foundation

class HttpClient {
    private var headers: [String: String]
    private var retry: Retry
    private var timeout: TimeInterval
    private var session: URLSession

    convenience init(defaultHeaders: [String: String] = [:], timeout: TimeInterval = 30.0, retry: Retry = .none) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        configuration.httpAdditionalHeaders = defaultHeaders

        self.init(
            session: URLSession(configuration: configuration),
            defaultHeaders: defaultHeaders,
            timeout: timeout,
            retry: retry)
    }

    init(
        session: URLSession, defaultHeaders: [String: String] = [:], timeout: TimeInterval = 30.0, retry: Retry = .none
    ) {
        self.headers = defaultHeaders
        self.retry = retry
        self.timeout = timeout
        self.session = session
    }

    func post<T: Decodable>(url: URL, data: Codable, resultType: T.Type) throws -> HttpClientResponse<T> {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let jsonData = try encoder.encode(data)
        request.httpBody = jsonData

        let result = try requestWithRetry(request: request)

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

    private func requestWithRetry(request: URLRequest) throws -> (response: HTTPURLResponse, data: Data?) {
        var retryWait: TimeInterval? = 0
        let retryHandler = self.retry.handler()

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

enum Retry {
    case none
    case exponential(maxBackoff: TimeInterval, maxAttempts: UInt)

    func handler() -> RetryHandler {
        switch self {
        case .none:
            return NoneRetryHandler()
        case let .exponential(maxBackoff, maxAttempts):
            return ExponentialBackoffRetryHandler(maxBackoff: maxBackoff, maxAttempts: maxAttempts)
        }
    }
}

protocol RetryHandler {
    func retryIn() -> TimeInterval?
}

class ExponentialBackoffRetryHandler: RetryHandler {
    private var currentAttempts: UInt = 0
    private let maxBackoff: TimeInterval
    private let maxAttempts: UInt

    init(maxBackoff: TimeInterval, maxAttempts: UInt) {
        self.maxBackoff = maxBackoff
        self.maxAttempts = maxAttempts
    }

    func retryIn() -> TimeInterval? {
        if currentAttempts >= maxAttempts {
            return nil
        }

        let nextRetryTime = min(pow(2, Double(currentAttempts)) + Double.random(in: 0..<1), maxBackoff)

        currentAttempts += 1
        return nextRetryTime
    }
}

class NoneRetryHandler: RetryHandler {
    func retryIn() -> TimeInterval? {
        return nil
    }
}

enum HttpClientError: Error {
    case invalidResponse
    case internalError
}
