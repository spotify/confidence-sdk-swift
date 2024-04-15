import Foundation
import Common
import XCTest

@testable import Confidence

// swiftlint:enable:next force_cast
class RemoteConfidenceClientTest: XCTestCase {
    override func setUp() {
        MockedClientURLProtocol.reset()
        super.setUp()
    }

    func testUploadDoesntThrow() async throws {
        let client = RemoteConfidenceClient(
            options: ConfidenceClientOptions(
                credentials: ConfidenceClientCredentials.clientSecret(secret: "")),
            session: MockedClientURLProtocol.mockedSession(),
            metadata: ConfidenceMetadata(name: "", version: ""))

        let processed = try await client.upload(batch: [
            ConfidenceEvent(
                name: "testEvent",
                payload: NetworkStruct.init(fields: [:]),
                time: Date.backport.nowISOString
            )
        ])
        XCTAssertTrue(processed)
    }

    func testUploadEmptyBatchDoesntThrow() async throws {
        let client = RemoteConfidenceClient(
            options: ConfidenceClientOptions(
                credentials: ConfidenceClientCredentials.clientSecret(secret: "")),
            session: MockedClientURLProtocol.mockedSession(),
            metadata: ConfidenceMetadata(name: "", version: ""))

        let processed = try await client.upload(batch: [])
        XCTAssertTrue(processed)
    }

    func testUploadFirstEventFailsDoesntThrow() async throws {
        MockedClientURLProtocol.mockedOperation = .firstEventFails
        let client = RemoteConfidenceClient(
            options: ConfidenceClientOptions(
                credentials: ConfidenceClientCredentials.clientSecret(secret: "")),
            session: MockedClientURLProtocol.mockedSession(),
            metadata: ConfidenceMetadata(name: "", version: ""))

        let processed = try await client.upload(batch: [
            ConfidenceEvent(
                name: "testEvent",
                payload: NetworkStruct.init(fields: [:]),
                time: Date.backport.nowISOString
            )
        ])
        XCTAssertTrue(processed)
    }

    func testBadRequestThrows() async throws {
        MockedClientURLProtocol.mockedOperation = .badRequest
        let client = RemoteConfidenceClient(
            options: ConfidenceClientOptions(
                credentials: ConfidenceClientCredentials.clientSecret(secret: "")),
            session: MockedClientURLProtocol.mockedSession(),
            metadata: ConfidenceMetadata(name: "", version: ""))

        var caughtError: ConfidenceError?
        do {
            _ = try await client.upload(batch: [
                ConfidenceEvent(
                    name: "testEvent",
                    payload: NetworkStruct.init(fields: [:]),
                    time: Date.backport.nowISOString
                )
            ])
        } catch {
            caughtError = error as! ConfidenceError?
        }
        let expectedError = ConfidenceError.badRequest(message: "explanation about malformed request")
        XCTAssertEqual(caughtError, expectedError)
    }

    func testNMalformedResponseThrows() async throws {
        MockedClientURLProtocol.mockedOperation = .malformedResponse
        let client = RemoteConfidenceClient(
            options: ConfidenceClientOptions(
                credentials: ConfidenceClientCredentials.clientSecret(secret: "")),
            session: MockedClientURLProtocol.mockedSession(),
            metadata: ConfidenceMetadata(name: "", version: ""))

        var caughtError: ConfidenceError?
        do {
            _ = try await client.upload(batch: [
                ConfidenceEvent(
                    name: "testEvent",
                    payload: NetworkStruct.init(fields: [:]),
                    time: Date.backport.nowISOString
                )
            ])
        } catch {
            caughtError = error as! ConfidenceError?
        }
        let expectedError = ConfidenceError.internalError(message: "invalidResponse")
        XCTAssertEqual(caughtError, expectedError)
    }
}
