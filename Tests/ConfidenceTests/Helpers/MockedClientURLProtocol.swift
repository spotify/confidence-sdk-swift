import Foundation
import XCTest

@testable import Confidence

class MockedClientURLProtocol: URLProtocol {
    public static var mockedOperation = MockedOperation.success

    enum MockedOperation {
        case firstEventFails
        case malformedResponse
        case badRequest
        case success
        case needRetryLater
    }

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
        MockedClientURLProtocol.mockedOperation = MockedOperation.success
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

        switch MockedClientURLProtocol.mockedOperation {
        case .badRequest:
            respondWithError(statusCode: 400, code: 0, message: "explanation about malformed request")
        case .needRetryLater:
            respondWithError(statusCode: 502, code: 0, message: "service unavailable")
        case .malformedResponse:
            malformedResponse()
        case .firstEventFails:
            respondWithSuccess(response: PublishEventResponse(errors: [
                EventError.init(index: 0, reason: .eventDefinitionNotFound, message: "")
            ]))
        case .success:
            respondWithSuccess(response: PublishEventResponse(errors: []))
        }
    }

    private func malformedResponse() {
        let response = URLResponse() // Malformed/Incomplete

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
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

extension URLRequest {
    public func decodeBody<T: Codable>(type: T.Type) -> T? {
        guard let bodyStream = self.httpBodyStream else { return nil }

        bodyStream.open()

        let bufferSize: Int = 128
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)

        var data = Data()
        while bodyStream.hasBytesAvailable {
            let readBytes = bodyStream.read(buffer, maxLength: bufferSize)
            data.append(buffer, count: readBytes)
        }

        buffer.deallocate()

        bodyStream.close()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(type, from: data)
        } catch {
            return nil
        }
    }
}
