import Foundation
import OpenFeature
import XCTest

@testable import ConfidenceProvider

@available(macOS 13.0, iOS 16.0, *)
class FlagApplierWithRetriesTest: XCTestCase {
    private let client = ClientMock()
    private let applyQueue = DispatchQueueFake()
    private let storage = StorageMock()

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
        let expectation = XCTestExpectation(description: "applied complete")
        let queue = DispatchQueueFakeSlow(expectation: expectation)

        let applier = FlagApplierWithRetries(client: client, applyQueue: queue, storage: storage)
        applier.apply(flagName: "flag1", resolveToken: "token1")
        wait(for: [expectation], timeout: 5.0)
        let readCache = try storage.load(CacheData.self, defaultValue: CacheData(data: [:]))
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

    func testApplyOffline_storesOnDisk() throws {
        let offlineClient = ClientMock(testMode: .error)
        let applier = FlagApplierWithRetries(client: offlineClient, applyQueue: applyQueue, storage: storage)

        applier.apply(flagName: "flag1", resolveToken: "token1")
        applier.apply(flagName: "flag2", resolveToken: "token1")
        applier.apply(flagName: "flag3", resolveToken: "token1")

        let storedData = try XCTUnwrap(storage.load(CacheData.self, defaultValue:  CacheData(data: [:])))

        XCTAssertEqual(storedData.data.count, 1)

        let data = try XCTUnwrap(storedData.data["token1"]?.data)
        XCTAssertEqual(data.count, 3)

        XCTAssertEqual(data["flag1"]?.count, 1)
        XCTAssertEqual(data["flag2"]?.count, 1)
        XCTAssertEqual(data["flag3"]?.count, 1)
    }

    func testApplyOffline_storesOnDisk_multipleTokens() throws {
        let offlineClient = ClientMock(testMode: .error)
        let applier = FlagApplierWithRetries(client: offlineClient, applyQueue: applyQueue, storage: storage)

        applier.apply(flagName: "flag1", resolveToken: "token1")
        applier.apply(flagName: "flag2", resolveToken: "token2")
        applier.apply(flagName: "flag3", resolveToken: "token3")

        let storedData = try XCTUnwrap(storage.load(CacheData.self, defaultValue:  CacheData(data: [:])))
        XCTAssertEqual(storedData.data.count, 3)

        let token1 = try XCTUnwrap(storedData.data["token1"]?.data)
        let token2 = try XCTUnwrap(storedData.data["token2"]?.data)
        let token3 = try XCTUnwrap(storedData.data["token3"]?.data)

        XCTAssertEqual(token1.count, 1)
        XCTAssertEqual(token1["flag1"]?.count, 1)

        XCTAssertEqual(token2.count, 1)
        XCTAssertEqual(token2["flag2"]?.count, 1)

        XCTAssertEqual(token3.count, 1)
        XCTAssertEqual(token3["flag3"]?.count, 1)
    }

    func testApply_doesNotstoreOnDisk() throws {
        let applier = FlagApplierWithRetries(client: client, applyQueue: applyQueue, storage: storage)

        applier.apply(flagName: "flag1", resolveToken: "token1")
        applier.apply(flagName: "flag2", resolveToken: "token1")
        applier.apply(flagName: "flag3", resolveToken: "token1")

        let expectation = XCTestExpectation(description: "applied complete")
        applyQueue.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        let storedData = try XCTUnwrap(storage.load(CacheData.self, defaultValue:  CacheData(data: [:])))
        XCTAssertEqual(storedData.data.count, 0)
    }

    func testApplyOffline_previoslyStoredData_storesOnDisk() throws {
        let offlineClient = ClientMock(testMode: .error)
        let prefilledStorage = StorageMock()
        let events = FlagEvents(data: ["flag0": [UUID(): Date()]])
        try prefilledStorage.save(data: CacheData(data: ["token0": events]))
        let applier = FlagApplierWithRetries(
            client: offlineClient,
            applyQueue: applyQueue,
            storage: prefilledStorage
        )

        applier.apply(flagName: "flag1", resolveToken: "token1")

        let storedData: CacheData = try XCTUnwrap(prefilledStorage.load(CacheData.self, defaultValue: CacheData(data: [:])))
        XCTAssertEqual(storedData.data.count, 2)
    }

    func testApplyOffline_previoslyStoredData_100records() throws {
        let offlineClient = ClientMock(testMode: .error)
        let prefilledStorage = StorageMock()
        let prefilledCache = try prefilledCacheData()
        try prefilledStorage.save(data: prefilledCache)
        let applier = FlagApplierWithRetries(
            client: offlineClient,
            applyQueue: applyQueue,
            storage: prefilledStorage
        )

        applier.apply(flagName: "flag1", resolveToken: "token1")

        let storedData: CacheData = try XCTUnwrap(prefilledStorage.load(CacheData.self, defaultValue: CacheData(data: [:])))
        XCTAssertEqual(storedData.data.count, 101)
    }

    func testApplyOffline_100applyCalls_differentTokens() throws {
        let offlineClient = ClientMock(testMode: .error)
        let prefilledStorage = StorageMock()
        let applier = FlagApplierWithRetries(
            client: offlineClient,
            applyQueue: applyQueue,
            storage: prefilledStorage
        )

        hundredApplyCalls(applier: applier, sameToken: false)

        let storedData: CacheData = try XCTUnwrap(prefilledStorage.load(CacheData.self, defaultValue: CacheData(data: [:])))
        XCTAssertEqual(storedData.data.count, 100)
    }

    func testApplyOffline_100applyCalls_sameToken() throws {
        let offlineClient = ClientMock(testMode: .error)
        let prefilledStorage = StorageMock()
        let applier = FlagApplierWithRetries(
            client: offlineClient,
            applyQueue: applyQueue,
            storage: prefilledStorage
        )

        hundredApplyCalls(applier: applier, sameToken: true)

        let storedData: CacheData = try XCTUnwrap(prefilledStorage.load(CacheData.self, defaultValue: CacheData(data: [:])))
        XCTAssertEqual(storedData.data.count, 1)
    }

    private func prefilledFlagEventsData() throws -> CacheData {
        var execution = 1, total = 100
        var flagEvents: FlagEvents = FlagEvents(data: [:])
        while (execution <= total) {
            let uuid = UUID()
            let date = Date(timeIntervalSince1970: Double(execution * 1000))
            flagEvents.data[uuid.uuidString] = [uuid: date]

            execution += 1
        }

        let cacheData = CacheData(data: ["token0": flagEvents])
        return cacheData
    }

    private func prefilledCacheData() throws -> CacheData {
        var execution = 1, total = 100
        var cacheData: CacheData = CacheData(data: [:])
        while (execution <= total) {
            let uuid = UUID()
            let date = Date(timeIntervalSince1970: Double(execution * 1000))
            let flagEvent = FlagEvents(data: [uuid.uuidString: [uuid: date]])
            cacheData.data[uuid.uuidString] = flagEvent

            execution += 1
        }

        return cacheData
    }

    private func hundredApplyCalls(applier: FlagAppier, sameToken: Bool = false) {
        var execution = 1, total = 100
        while (execution <= total) {
            let uuid = UUID()
            let token = sameToken ? "token" : uuid.uuidString
            applier.apply(flagName: uuid.uuidString, resolveToken: token)

            execution += 1
        }
    }
}
