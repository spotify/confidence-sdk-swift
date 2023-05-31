import Foundation
import OpenFeature
import XCTest

@testable import ConfidenceProvider

@available(macOS 13.0, iOS 16.0, *)
class FlagApplierWithRetriesTest: XCTestCase {
    private let client = MockedClient()
    private let applyQueue = DispatchQueueFake()
    private let storage = MockStorage()

    override func setUp() {
        try? storage.clear()
        client.applyCount = 0

        super.setUp()
    }

    func testSimpleApply() {
        let applier = FlagApplierWithRetries(client: client, applyQueue: applyQueue, storage: storage)
        applier.apply(flagName: "flag1", resolveToken: "token1")
        applier.apply(flagName: "flag1", resolveToken: "token1")
        applier.apply(flagName: "flag1", resolveToken: "token1")
        XCTAssertEqual(client.applyCount, 3)
    }

    func testApplyMap() {
        let applier = FlagApplierWithRetries(client: client, applyQueue: applyQueue, storage: storage)
        applier.apply(flagName: "flag1", resolveToken: "token1")
        applier.apply(flagName: "flag2", resolveToken: "token2")
        applier.apply(flagName: "flag3", resolveToken: "token3")
        XCTAssertEqual(client.applyCount, 3)
    }

    func testCacheFileOperations() throws {
        let fileDG = DispatchGroup()
        let expectation = XCTestExpectation(description: "applied complete")
        let queue = DispatchQueueFakeSlow(expectation: expectation)

        let applier = FlagApplierWithRetries(client: client, applyQueue: queue, storage: storage, fileDG: fileDG)
        applier.apply(flagName: "flag1", resolveToken: "token1")
        _ = fileDG.wait(timeout: DispatchTime.now() + 3)
        wait(for: [expectation], timeout: 5.0)
        let readCache = try storage.load(
            FlagApplierWithRetries.CacheData.self, defaultValue: FlagApplierWithRetries.CacheData(data: [:]))
        XCTAssertTrue(readCache.data.isEmpty)
        XCTAssertEqual(client.applyCount, 1)
    }

    func testSlowApply() {
        let expectation = XCTestExpectation(description: "applied complete")
        expectation.expectedFulfillmentCount = 3
        let queue = DispatchQueueFakeSlow(expectation: expectation)
        let applier = FlagApplierWithRetries(client: client, applyQueue: queue, storage: storage)
        applier.apply(flagName: "flag1", resolveToken: "token1")
        applier.apply(flagName: "flag1", resolveToken: "token1")
        wait(for: [expectation], timeout: 3.0)
        // Expect in-flight events to be-resent
        XCTAssertEqual(client.applyCount, 3)
    }
}

class MockedClient: ConfidenceClient {
    var applyCount = 0

    func resolve(ctx: EvaluationContext) throws -> ResolvesResult {
        return ResolvesResult(resolvedValues: [], resolveToken: "")
    }

    func apply(flag: String, resolveToken: String, applyTime: Date) throws {
        applyCount += 1
    }

    func resolve(flag: String, ctx: EvaluationContext) throws -> ResolveResult {
        return ResolveResult(resolvedValue: ResolvedValue(flag: "flag1"), resolveToken: "")
    }
}

class MockStorage: Storage {
    var data = ""

    func save(data: Encodable) throws {
        let dataB = try JSONEncoder().encode(data)
        self.data = String(data: dataB, encoding: .utf8) ?? ""
    }

    func load<T>(_ type: T.Type, defaultValue: T) throws -> T where T: Decodable {
        if data.isEmpty {
            return defaultValue
        }
        return try JSONDecoder().decode(type, from: data.data)
    }

    func clear() throws {
        data = ""
    }
}
