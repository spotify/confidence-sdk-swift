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
        case error
    }

    init(testMode: TestMode = .success) {
        self.testMode = testMode
    }

    func post<T>(path: String, data: Codable, resultType: T.Type) throws -> HttpClientResponse<T> where T: Decodable {
        defer {
            expectation?.fulfill()
        }

        postCallCounter += 1
        self.data == nil ? self.data = [data] : self.data?.append(data)

        switch testMode {
        case .success:
            return HttpClientResponse(response: HTTPURLResponse())
        case .error:
            throw HttpClientError.invalidResponse
        }
    }
}
