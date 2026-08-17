import Combine
import ConfidenceProvider
import Foundation
import OpenFeature
import XCTest

@testable import Confidence

final class ProviderTrackIntegrationTest: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        OpenFeatureAPI.shared.clearProvider()
        try cleanEventStorageFolder()
    }

    override func tearDown() async throws {
        await OpenFeatureAPI.shared.clearProviderAndWait()
        try await super.tearDown()
    }

    func testOpenFeatureTrackPersistsEventToDisk() async throws {
        let targetingKey = UUID().uuidString
        let initialContext = ImmutableContext(
            targetingKey: targetingKey,
            structure: ImmutableStructure(attributes: [
                "user": .structure(["country": .string("SE")])
            ])
        )

        let confidence = Confidence.Builder(clientSecret: "test-client-secret")
            .withFlagResolverClient(flagResolver: EmptyResolveClient())
            .build()

        let provider = ConfidenceFeatureProvider(
            confidence: confidence,
            initializationStrategy: .activateAndFetchAsync
        )

        let cancellable = provider.observe().sink { _ in }

        await OpenFeatureAPI.shared.setProviderAndWait(provider: provider, initialContext: initialContext)
        XCTAssertEqual(OpenFeatureAPI.shared.getProviderStatus(), .ready)

        let folderURL = try EventStorageImpl.getFolderURL()
        let inFlightFiles = try inFlightBatchFiles(in: folderURL)
        XCTAssertEqual(inFlightFiles.count, 1)
        XCTAssertTrue(try readInFlightEvents(from: folderURL).isEmpty)

        OpenFeatureAPI.shared.getClient().track(
            key: "MyEventName",
            details: ImmutableTrackingEventDetails(
                value: 33.0,
                structure: ImmutableStructure(attributes: ["key": .string("value")])
            )
        )

        let events = try await waitForInFlightEvents(count: 1)
        let event = try XCTUnwrap(events.first)
        XCTAssertEqual(event.name, "MyEventName")
        XCTAssertEqual(event.payload["value"], ConfidenceValue(double: 33.0))
        XCTAssertEqual(event.payload["key"], ConfidenceValue(string: "value"))

        let context = try XCTUnwrap(event.payload["context"]?.asStructure())
        XCTAssertEqual(context["targeting_key"], ConfidenceValue(string: targetingKey))
        XCTAssertNotNil(context["visitor_id"]?.asString())
        XCTAssertEqual(
            context["user"]?.asStructure()?["country"],
            ConfidenceValue(string: "SE")
        )

        cancellable.cancel()
    }

    private func cleanEventStorageFolder() throws {
        let folderURL = try EventStorageImpl.getFolderURL()
        if FileManager.default.fileExists(atPath: folderURL.path) {
            try FileManager.default.removeItem(at: folderURL)
        }
    }

    private func inFlightBatchFiles(in folderURL: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension != "READY" }
    }

    private func readInFlightEvents(from folderURL: URL) throws -> [ConfidenceEvent] {
        guard let currentFile = try inFlightBatchFiles(in: folderURL).first else {
            return []
        }

        let data = try Data(contentsOf: currentFile)
        guard let dataString = String(data: data, encoding: .utf8) else {
            return []
        }

        let decoder = JSONDecoder()
        return try dataString.components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .map { line in
                guard let lineData = line.data(using: .utf8) else {
                    throw ConfidenceError.internalError(message: "Invalid event line encoding")
                }
                return try decoder.decode(ConfidenceEvent.self, from: lineData)
            }
    }

    private func waitForInFlightEvents(count: Int, timeout: TimeInterval = 5.0) async throws -> [ConfidenceEvent] {
        let folderURL = try EventStorageImpl.getFolderURL()
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let events = try readInFlightEvents(from: folderURL)
            if events.count == count {
                return events
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTFail("Timed out waiting for \(count) in-flight event(s)")
        return []
    }
}

private struct EmptyResolveClient: ConfidenceResolveClient {
    func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
        .init(resolvedValues: [], resolveToken: "token")
    }
}
