import Foundation

final class NetworkClient: HttpClient {
    private let headers: [String: String]
    private let retry: Retry
    private let session: URLSession
    private let baseUrl: String
    private var timeoutIntervalForRequests: Double

    public init(
        session: URLSession? = nil,
        baseUrl: String,
        defaultHeaders: [String: String] = [:],
        retry: Retry = .none,
        timeoutIntervalForRequests: Double
    ) {
        self.session =
        session
        ?? {
            let configuration = URLSessionConfiguration.default
            configuration.httpAdditionalHeaders = defaultHeaders

            return URLSession(configuration: configuration)
        }()

        self.headers = defaultHeaders
        self.retry = retry
        self.baseUrl = baseUrl
        self.timeoutIntervalForRequests = timeoutIntervalForRequests
    }

    func post<T>(path: String, data: any Encodable, header: any Encodable) async throws -> HttpClientResult<T> where T : Decodable {
        let request = try buildRequest(path: path, data: data, header: header)
        return try await post(request: request)
    }

    public func post<T: Decodable>(
        path: String,
        data: Encodable
    ) async throws -> HttpClientResult<T> {
        let request = try buildRequest(path: path, data: data)
        return try await post(request: request)
    }

    private func post<T: Decodable>(
        request: URLRequest
    ) async throws -> HttpClientResult<T>  {
        let requestResult = await perform(request: request, retry: self.retry)
        if let error = requestResult.error {
            return .failure(error)
        }

        guard let response = requestResult.httpResponse, let data = requestResult.data else {
            return .failure(ConfidenceError.internalError(message: "Bad response"))
        }

        do {
            let httpClientResult: HttpClientResponse<T> =
            try self.buildResponse(response: response, data: data)
            return .success(httpClientResult)
        } catch {
            return .failure(error)
        }
    }

    private func perform(
        request: URLRequest,
        retry: Retry
    ) async -> RequestResult {
        let retryHandler = retry.handler()
        let retryWait: TimeInterval? = retryHandler.retryIn()

        do {
            let (data, response) = try await self.session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return RequestResult(httpResponse: nil, data: nil, error: HttpClientError.invalidResponse)
            }
            if self.shouldRetry(httpResponse: httpResponse), let retryWait {
                try? await Task.sleep(nanoseconds: UInt64(retryWait * 1_000_000_000))
                return await self.perform(request: request, retry: retry)
            }
            return RequestResult(httpResponse: httpResponse, data: data, error: nil)
        } catch {
            if self.shouldRetry(error: error), let retryWait {
                try? await Task.sleep(nanoseconds: UInt64(retryWait * 1_000_000_000))
                return await self.perform(request: request, retry: retry)
            } else {
                return RequestResult(httpResponse: nil, data: nil, error: error)
            }
        }
    }
}

struct RequestResult {
    var httpResponse: HTTPURLResponse?
    var data: Data?
    var error: Error?
}

// MARK: Private

extension NetworkClient {
    private func constructURL(base: String, path: String) -> URL? {
        let normalisedBase = base.hasSuffix("/") ? base : "\(base)"
        let normalisedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path

        return URL(string: "\(normalisedBase)\(normalisedPath)")
    }

    private func buildRequest(path: String, data: Encodable, header: Encodable? = nil) throws -> URLRequest {
        guard let url = constructURL(base: baseUrl, path: path) else {
            throw ConfidenceError.internalError(message: "Could not create service url")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")


        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let header = header {
            let jsonHeaderData = try encoder.encode(header)

            if let headerJsonString = String(data: jsonHeaderData, encoding: .utf8) {
                request.addValue(headerJsonString, forHTTPHeaderField: "Confidence-Metadata")
            }
        }
        // TMP - TESTING
        if let headers = request.allHTTPHeaderFields, let metadata = headers["Confidence-Metadata"] {
            if let data = metadata.data(using: .utf8) {
                do {
                    let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                    let prettyData = try JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted)

                    if let prettyPrintedString = String(data: prettyData, encoding: .utf8) {
                        print(prettyPrintedString)
                    }
                } catch {
                    print("Failed to pretty print JSON: \(error)")
                }
            }
        }

        let jsonData = try encoder.encode(data)
        request.httpBody = jsonData

        return request
    }

    private func buildResponse<T: Decodable>(
        response httpURLResponse: HTTPURLResponse?,
        data: Data?
    ) throws -> HttpClientResponse<T> {
        guard let httpURLResponse else {
            throw ConfidenceError.internalError(message: "Invalid response")
        }

        var response: HttpClientResponse<T> = HttpClientResponse(response: httpURLResponse)
        if let responseData = data {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if response.response.status == .ok {
                response.decodedData = try decoder.decode(T.self, from: responseData)
            } else {
                do {
                    response.decodedError = try decoder.decode(HttpError.self, from: responseData)
                } catch {
                    let message = String(data: responseData, encoding: .utf8)
                    response.decodedError = HttpError(
                        code: httpURLResponse.statusCode,
                        message: message ?? "{Error when decoding error message}",
                        details: []
                    )
                }
            }
        }

        return response
    }

    private func shouldRetry(httpResponse: HTTPURLResponse) -> Bool {
        httpResponse.status?.responseType == .serverError
    }

    private func shouldRetry(error: Error) -> Bool {
        (error as? URLError)?.code == .timedOut
    }
}
