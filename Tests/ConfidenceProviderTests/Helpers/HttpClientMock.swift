import Foundation
import XCTest

@testable import ConfidenceProvider

final class HttpClientMock: HttpClient {
    var testMode: TestMode
    var postCallCounter = 0
    var data: [Codable]?
    var expectation: XCTestExpectation?

    enum TestMode {
        case success
        case failFirstChunk
        case offline
    }

    init(testMode: TestMode = .success) {
        self.testMode = testMode
    }

    func post<T>(
        path: String,
        data: Codable,
        completion: @escaping (ConfidenceProvider.HttpClientResult<T>) async -> Void
    ) async throws where T: Decodable {
        do {
            let result: HttpClientResponse<T> = try handlePost(path: path, data: data)
            await completion(.success(result))
        } catch {
            await completion(.failure(error))
        }
    }

    func post<T>(
        path: String, data: Codable
    ) async throws -> ConfidenceProvider.HttpClientResponse<T> where T: Decodable {
        try handlePost(path: path, data: data)
    }

    func post<T>(
        path: String, data: Codable
    ) throws -> ConfidenceProvider.HttpClientResponse<T> where T: Decodable {
        try handlePost(path: path, data: data)
    }

    private func handlePost<T>(
        path: String, data: Codable
    ) throws -> ConfidenceProvider.HttpClientResponse<T> where T: Decodable {
        defer {
            expectation?.fulfill()
        }

        postCallCounter += 1
        self.data == nil ? self.data = [data] : self.data?.append(data)

        switch testMode {
        case .success:
            return HttpClientResponse(response: HTTPURLResponse())
        case .failFirstChunk:
            if postCallCounter == 1 {
                throw HttpClientError.invalidResponse
            } else {
                return HttpClientResponse(response: HTTPURLResponse())
            }
        case .offline:
            throw HttpClientError.invalidResponse
        }
    }
}
