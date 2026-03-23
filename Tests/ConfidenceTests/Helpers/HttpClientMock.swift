import Foundation
import XCTest

@testable import Confidence

final class HttpClientMock: HttpClient {
    var testMode: TestMode
    var postCallCounter = 0
    var data: [Encodable]?
    var headers: [[String: String]] = []
    var expectation: XCTestExpectation?

    enum TestMode {
        case success
        case failFirstChunk
        case offline
    }

    init(testMode: TestMode = .success) {
        self.testMode = testMode
    }

    func post<T>(path: String, data: Encodable, headers: [String: String]) async throws -> HttpClientResult<T>
    where T: Decodable {
        try handlePost(path: path, data: data, headers: headers)
    }

    private func handlePost<T>(
        path: String, data: Encodable, headers: [String: String]
    ) throws -> HttpClientResult<T> where T: Decodable {
        defer {
            expectation?.fulfill()
        }

        postCallCounter += 1
        self.data == nil ? self.data = [data] : self.data?.append(data)
        self.headers.append(headers)

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
