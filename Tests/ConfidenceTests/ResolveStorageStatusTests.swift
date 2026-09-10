import Foundation
import XCTest

@testable import Confidence

class ResolveStorageStatusTests: XCTestCase {
    func testMaxAgeBoundaries() {
        let now = Date(timeIntervalSince1970: 10_000)
        let check = MaxAgeStorageCheck(maxAge: 100) { now }
        XCTAssertEqual(check.check(metadata: metadata(isEmpty: true)), .empty)
        XCTAssertEqual(check.check(metadata: metadata()), .stale(lastFetchedAt: nil))
        for age in [99.0, 100.0, 101.0, -1.0] {
            let fetchedAt = now.addingTimeInterval(-age)
            XCTAssertEqual(
                check.check(metadata: metadata(lastFetchedAt: fetchedAt)),
                age >= 100 ? .stale(lastFetchedAt: fetchedAt) : .fresh(lastFetchedAt: fetchedAt)
            )
        }
    }

    func testLegacyAndFutureCacheFields() throws {
        let data = Data("""
        {"context":{},"flags":[],"resolveToken":"token","futureField":true}
        """.utf8)
        let resolution = try JSONDecoder().decode(FlagResolution.self, from: data)
        XCTAssertNil(resolution.lastFetchedAt)
        let storage = try StorageMock(data: resolution)
        let confidence = makeConfidence(storage: storage)
        defer { confidence.stop() }
        XCTAssertEqual(
            try confidence.getStorageStatus(check: MaxAgeStorageCheck(maxAge: 100)),
            .stale(lastFetchedAt: nil)
        )
    }

    func testFetchPersistsMetadataWithoutActivationAndFailurePreservesIt() async throws {
        let storage = StorageMock()
        let resolver = StatusResolver()
        let confidence = makeConfidence(storage: storage, resolver: resolver)
        defer { confidence.stop() }
        let check = MaxAgeStorageCheck(maxAge: 100)
        XCTAssertEqual(try confidence.getStorageStatus(check: check), .empty)

        let before = Date()
        await confidence.asyncFetch()
        let saved = try storage.load(defaultValue: FlagResolution.EMPTY)
        let fetchedAt = try XCTUnwrap(saved.lastFetchedAt)
        XCTAssertGreaterThanOrEqual(fetchedAt, before)
        XCTAssertLessThanOrEqual(fetchedAt, Date())
        XCTAssertEqual(saved.context, confidence.getContext())
        XCTAssertEqual(try confidence.getStorageStatus(check: check), .fresh(lastFetchedAt: fetchedAt))

        let recreated = makeConfidence(storage: storage)
        defer { recreated.stop() }
        XCTAssertEqual(try recreated.getStorageStatus(check: check), .fresh(lastFetchedAt: fetchedAt))
        XCTAssertEqual(try recreated.getStorageStatus(check: ContextCheck()), .fresh(lastFetchedAt: fetchedAt))

        resolver.shouldFail = true
        await confidence.asyncFetch()
        XCTAssertEqual(try storage.load(defaultValue: FlagResolution.EMPTY), saved)
        try storage.clear()
        XCTAssertEqual(try confidence.getStorageStatus(check: check), .empty)
    }

    func testCorruptStorageThrows() throws {
        let storage = StorageMock()
        storage.data = "invalid json"
        let confidence = makeConfidence(storage: storage)
        defer { confidence.stop() }
        XCTAssertThrowsError(try confidence.getStorageStatus(check: MaxAgeStorageCheck(maxAge: 100)))
    }

    private func metadata(isEmpty: Bool = false, lastFetchedAt: Date? = nil) -> ResolveStorageMetadata {
        ResolveStorageMetadata(isEmpty: isEmpty, lastFetchedAt: lastFetchedAt, context: [:])
    }

    private func makeConfidence(
        storage: Storage,
        resolver: ConfidenceResolveClient = StatusResolver()
    ) -> Confidence {
        Confidence.Builder(clientSecret: "", loggerLevel: .NONE)
            .withStorage(storage: storage)
            .withFlagResolverClient(flagResolver: resolver)
            .withContext(initialContext: ["targeting_key": .init(string: "user")])
            .build()
    }
}

private struct ContextCheck: ResolveStorageCheck {
    func check(metadata: ResolveStorageMetadata) -> ResolveStorageStatus {
        XCTAssertEqual(metadata.context["targeting_key"], .init(string: "user"))
        XCTAssertFalse(metadata.isEmpty)
        return .fresh(lastFetchedAt: metadata.lastFetchedAt)
    }
}

private class StatusResolver: ConfidenceResolveClient {
    var shouldFail = false

    func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
        if shouldFail {
            throw HttpClientError.invalidResponse
        }
        return ResolvesResult(resolvedValues: [], resolveToken: "token")
    }
}
