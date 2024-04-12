import Foundation
import Common
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

        try await client.upload(batch: [
            ConfidenceClientEvent(definition: "testEvent", payload: NetworkStruct.init(fields: [:]))
        ])
    }

    func testUploadEmptyBatchDoesntThrow() async throws {
        let client = RemoteConfidenceClient(
            options: ConfidenceClientOptions(
                credentials: ConfidenceClientCredentials.clientSecret(secret: "")),
            session: MockedClientURLProtocol.mockedSession(),
            metadata: ConfidenceMetadata(name: "", version: ""))

        try await client.upload(batch: [])
    }

    func testUploadFirstEventFailsDoesntThrow() async throws {
        MockedClientURLProtocol.firstEventFails = true
        let client = RemoteConfidenceClient(
            options: ConfidenceClientOptions(
                credentials: ConfidenceClientCredentials.clientSecret(secret: "")),
            session: MockedClientURLProtocol.mockedSession(),
            metadata: ConfidenceMetadata(name: "", version: ""))

        try await client.upload(batch: [
            ConfidenceClientEvent(definition: "testEvent", payload: NetworkStruct.init(fields: [:]))
        ])
    }
}
