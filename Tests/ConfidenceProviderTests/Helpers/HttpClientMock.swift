import Foundation

@testable import ConfidenceProvider

final class HttpClientMock: HttpClient {
    var testMode: TestMode
    var postCallCounter = 0
    var data: Codable?

    enum TestMode {
        case success
        case error
    }

    init(testMode: TestMode = .success) {
        self.testMode = testMode
    }

    func post<T>(path: String, data: Codable, resultType: T.Type) throws -> HttpClientResponse<T> where T: Decodable {
        postCallCounter += 1
        self.data = data

        switch testMode {
        case .success:
            return HttpClientResponse(response: HTTPURLResponse())
        case .error:
            throw HttpClientError.invalidResponse
        }
    }
}
