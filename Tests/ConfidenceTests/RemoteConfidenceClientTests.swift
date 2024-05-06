import Foundation
import XCTest

@testable import Confidence

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

        let processed = try await client.upload(events: [
            NetworkEvent(
                eventDefinition: "testEvent",
                payload: NetworkStruct.init(fields: [:]),
                eventTime: Date.backport.nowISOString
            )
        ])
        XCTAssertTrue(processed)
    }

    func testUploadEmptyEventsDoesntThrow() async throws {
        let client = RemoteConfidenceClient(
            options: ConfidenceClientOptions(
                credentials: ConfidenceClientCredentials.clientSecret(secret: "")),
            session: MockedClientURLProtocol.mockedSession(),
            metadata: ConfidenceMetadata(name: "", version: ""))

        let processed = try await client.upload(events: [])
        XCTAssertTrue(processed)
    }

    func testUploadFirstEventFailsDoesntThrow() async throws {
        MockedClientURLProtocol.mockedOperation = .firstEventFails
        let client = RemoteConfidenceClient(
            options: ConfidenceClientOptions(
                credentials: ConfidenceClientCredentials.clientSecret(secret: "")),
            session: MockedClientURLProtocol.mockedSession(),
            metadata: ConfidenceMetadata(name: "", version: ""))

        let processed = try await client.upload(events: [
            NetworkEvent(
                eventDefinition: "testEvent",
                payload: NetworkStruct.init(fields: [:]),
                eventTime: Date.backport.nowISOString
            )
        ])
        XCTAssertTrue(processed)
    }

    func testMalformedResponseThrows() async throws {
        MockedClientURLProtocol.mockedOperation = .malformedResponse
        let client = RemoteConfidenceClient(
            options: ConfidenceClientOptions(
                credentials: ConfidenceClientCredentials.clientSecret(secret: "")),
            session: MockedClientURLProtocol.mockedSession(),
            metadata: ConfidenceMetadata(name: "", version: ""))

        var caughtError: ConfidenceError?
        do {
            _ = try await client.upload(events: [
                NetworkEvent(
                    eventDefinition: "testEvent",
                    payload: NetworkStruct.init(fields: [:]),
                    eventTime: Date.backport.nowISOString
                )
            ])
        } catch {
            // swiftlint:disable:next force_cast 
            caughtError = error as! ConfidenceError?
        }
        let expectedError = ConfidenceError.internalError(message: "invalidResponse")
        XCTAssertEqual(caughtError, expectedError)
    }
}
