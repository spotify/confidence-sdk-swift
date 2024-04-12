import Foundation
import Common
import XCTest

@testable import Confidence

class MockedClientURLProtocol: URLProtocol {
    public static var firstEventFails = false

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
        case _ where path.hasSuffix("/events:publish"):
            return upload()
        default:
            client?.urlProtocol(self, didFailWithError: NSError(domain: "test", code: URLError.badURL.rawValue))
            return
        }
    }

    override func stopLoading() {
        // This is called if the request gets canceled or completed.
    }

    static func mockedSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.protocolClasses = [MockedClientURLProtocol.self]
        return URLSession(configuration: config)
    }

    static func reset() {
        MockedClientURLProtocol.firstEventFails = false
    }

    private func upload() {
        guard let request = request.decodeBody(type: PublishEventRequest.self) else {
            client?.urlProtocol(
                self, didFailWithError: NSError(domain: "test", code: URLError.cannotDecodeRawData.rawValue))
            return
        }

        XCTAssertNotNil(request.clientSecret)
        XCTAssertNotNil(request.sendTime)
        XCTAssertNotEqual(request.sendTime, "")

        if MockedClientURLProtocol.firstEventFails {
            respondWithSuccess(response: PublishEventResponse(errors: [
                EventError.init(index: 0, reason: .eventDefinitionNotFound, message: "")
            ]))
        } else {
            respondWithSuccess(response: PublishEventResponse(errors: []))
        }
    }

    private func respondWithError(statusCode: Int, code: Int, message: String) {
        let error = HttpError(code: code, message: message, details: [])
        let errorData = try? JSONEncoder().encode(error)

        let response = HTTPURLResponse(
            // swiftlint:disable:next force_unwrapping
            url: request.url!, statusCode: statusCode, httpVersion: "", headerFields: [:])!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let errorData = errorData {
            client?.urlProtocol(self, didLoad: errorData)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    private func respondWithSuccess(response: Codable) {
        // swiftlint:disable:next force_unwrapping
        let httpResponse = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "", headerFields: [:])!

        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)

        if let data = try? JSONEncoder().encode(response) {
            client?.urlProtocol(self, didLoad: data)
        }

        client?.urlProtocolDidFinishLoading(self)
    }
}
