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
                credentials: ConfidenceClientCredentials.clientSecret(secret: ""), timeoutIntervalForRequest: 10),
            session: MockedClientURLProtocol.mockedSession(),
            telemetry: Telemetry(sdkId: "", library: .confidence, libraryVersion: ""))

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
                credentials: ConfidenceClientCredentials.clientSecret(secret: ""), timeoutIntervalForRequest: 10),
            session: MockedClientURLProtocol.mockedSession(),
            telemetry: Telemetry(sdkId: "", library: .confidence, libraryVersion: ""))

        let processed = try await client.upload(events: [])
        XCTAssertTrue(processed)
    }

    func testUploadIgnoresCustomResolveBaseUrl() async throws {
        let client = RemoteConfidenceClient(
            options: ConfidenceClientOptions(
                credentials: ConfidenceClientCredentials.clientSecret(secret: ""),
                region: .europe,
                resolveBaseUrl: "http://localhost:8090",
                timeoutIntervalForRequest: 10
            ),
            session: MockedClientURLProtocol.mockedSession(),
            telemetry: Telemetry(sdkId: "", library: .confidence, libraryVersion: "")
        )

        _ = try await client.upload(events: [])

        XCTAssertEqual(
            MockedClientURLProtocol.lastRequestURL?.absoluteString,
            "https://events.eu.confidence.dev/v1/events:publish"
        )
    }

    func testUploadFirstEventFailsDoesntThrow() async throws {
        MockedClientURLProtocol.mockedOperation = .firstEventFails
        let client = RemoteConfidenceClient(
            options: ConfidenceClientOptions(
                credentials: ConfidenceClientCredentials.clientSecret(secret: ""), timeoutIntervalForRequest: 10),
            session: MockedClientURLProtocol.mockedSession(),
            telemetry: Telemetry(sdkId: "", library: .confidence, libraryVersion: ""))

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
                credentials: ConfidenceClientCredentials.clientSecret(secret: ""), timeoutIntervalForRequest: 10),
            session: MockedClientURLProtocol.mockedSession(),
            telemetry: Telemetry(sdkId: "", library: .confidence, libraryVersion: ""))

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
