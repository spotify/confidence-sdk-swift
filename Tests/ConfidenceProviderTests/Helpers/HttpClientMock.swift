import Foundation
import XCTest

@testable import Confidence

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

    func post<T>(path: String, data: Codable) async throws -> HttpClientResult<T> where T: Decodable {
        try handlePost(path: path, data: data)
    }

    private func handlePost<T>(
        path: String, data: Codable
    ) throws -> HttpClientResult<T> where T: Decodable {
        defer {
            expectation?.fulfill()
        }

        postCallCounter += 1
        self.data == nil ? self.data = [data] : self.data?.append(data)

        switch testMode {
        case .success:
            return .success(HttpClientResponse(response: HTTPURLResponse()))
        case .failFirstChunk:
            if postCallCounter == 1 {
                throw HttpClientError.invalidResponse
            } else {
                return .success(HttpClientResponse(response: HTTPURLResponse()))
            }
        case .offline:
            throw HttpClientError.invalidResponse
        }
    }
}
