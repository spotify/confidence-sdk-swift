import Foundation
import XCTest

@testable import Confidence

final class HttpClientMock: HttpClient {
    var testMode: TestMode
    var postCallCounter = 0
    var data: [Encodable]?
    var expectation: XCTestExpectation?

    enum TestMode {
        case success
        case failFirstChunk
        case offline
    }

    init(testMode: TestMode = .success) {
        self.testMode = testMode
    }

    func post<T>(path: String, data: Encodable) async throws -> HttpClientResult<T> where T: Decodable {
        try handlePost(path: path, data: data)
    }

    func post<T>(path: String, data: any Encodable, header: Data) async throws -> HttpClientResult<T> where T : Decodable {
        try handlePost(path: path, data: data)
    }

    private func handlePost<T>(
        path: String, data: Encodable
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
