import Foundation

final class NetworkClient: HttpClient {
    private let headers: [String: String]
    private let retry: Retry
    private let timeout: TimeInterval
    private let session: URLSession
    private let region: ConfidenceRegion

    private var baseUrl: String {
        switch region {
        case .global:
            return "https://resolver.confidence.dev/v1/flags"
        case .europe:
            return "https://resolver.eu.confidence.dev/v1/flags"
        case .usa:
            return "https://resolver.us.confidence.dev/v1/flags"
        }
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

    func post<T: Decodable>(
        path: String,
        data: Codable,
        completion: @escaping (HttpClientResult<T>) async -> Void
    ) async throws {
        let request = try buildRequest(path: path, data: data)
        await perform(request: request, retry: self.retry) { response, data, error in
            if let error {
                await completion(.failure(error))
                return
            }

            guard let response, let data else {
                await completion(.failure(ConfidenceError.internalError(message: "Bad response")))
                return
            }

            do {
                let httpClientResult: HttpClientResponse<T> =
                try self.buildResponse(response: response, data: data)
                await completion(.success(httpClientResult))
            } catch {
                await completion(.failure(error))
            }
        }
    }

    private func perform(
        request: URLRequest,
        retry: Retry,
        completion: @escaping (HTTPURLResponse?, Data?, Error?) async -> Void
    ) async {
        let retryHandler = retry.handler()
        let retryWait: TimeInterval? = retryHandler.retryIn()

        do {
            let (data, response) = try await self.session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                await completion(nil, nil, HttpClientError.invalidResponse)
                return
            }
            if self.shouldRetry(httpResponse: httpResponse), let retryWait {
                try? await Task.sleep(nanoseconds: UInt64(retryWait * 1_000_000_000))
                await self.perform(request: request, retry: retry, completion: completion)
                return
            }
            await completion(httpResponse, data, nil)
        } catch {
            if self.shouldRetry(error: error), let retryWait {
                try? await Task.sleep(nanoseconds: UInt64(retryWait * 1_000_000_000))
                await self.perform(request: request, retry: retry, completion: completion)
            } else {
                await completion(nil, nil, error)
            }
        }
    }

    // MARK: Async

    func post<T: Decodable>(path: String, data: Codable) async throws -> HttpClientResponse<T> {
        let request = try buildRequest(path: path, data: data)
        let result = try await perform(request: request, retry: self.retry)

        return try buildResponse(response: result.response, data: result.data)
    }

    private func perform(
        request: URLRequest,
        retry: Retry
    ) async throws -> (response: HTTPURLResponse, data: Data?) {
        let retryHandler = retry.handler()
        let retryWait: TimeInterval? = retryHandler.retryIn()

        var resultData: Data?
        var resultResponse: HTTPURLResponse?

        do {
            let result: (Data, URLResponse) = try await self.session.data(for: request)

            guard let httpResponse = result.1 as? HTTPURLResponse else {
                throw HttpClientError.invalidResponse
            }

            if shouldRetry(httpResponse: httpResponse) {
                if let retryWait {
                    try await Task.sleep(nanoseconds: UInt64(retryWait * 1_000_000_000))
                    return try await perform(request: request, retry: retry)
                }
            }

            resultData = result.0
            resultResponse = httpResponse
        } catch {
            if shouldRetry(error: error) {
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
}

// MARK: Private

extension NetworkClient {
    private func constructURL(base: String, path: String) -> URL? {
        let normalisedBase = base.hasSuffix("/") ? base : "\(base)"
        let normalisedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path

        return URL(string: "\(normalisedBase)\(normalisedPath)")
    }

    private func buildRequest(path: String, data: Codable) throws -> URLRequest {
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
                    let message = String(data: responseData, encoding: String.Encoding.utf8)
                    response.decodedError = HttpError(
                        code: httpURLResponse.statusCode,
                        message: message ?? "unknown",
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
