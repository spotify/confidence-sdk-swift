import Foundation
import Common
import Confidence

class MockedClientURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let path = request.url?.absoluteString, request.httpMethod == "POST" else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "test", code: URLError.badURL.rawValue))
            return
        }

        switch path {
        case _ where path.hasSuffix("/events:upload"):
            return // TODO
        default:
            client?.urlProtocol(self, didFailWithError: NSError(domain: "test", code: URLError.badURL.rawValue))
            return
        }
    }

    override func stopLoading() {
        // This is called if the request gets canceled or completed.
    }
}
