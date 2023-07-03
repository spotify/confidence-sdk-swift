import Foundation
import OpenFeature
import XCTest

@testable import ConfidenceProvider

final class CacheDataTests: XCTestCase {
    func testCacheData_addEvent_emptyCache() throws {
        let applyTime = Date()
        var cacheData = CacheData(resolveToken: "token1", events: [])
        cacheData.add(resolveToken: "token1", flagName: "flagName", applyTime: applyTime)

        XCTAssertEqual(cacheData.resolveEvents.count, 1)

        let resolveEvent = try XCTUnwrap(cacheData.resolveEvents.first)

        XCTAssertEqual(resolveEvent.resolveToken, "token1")
        XCTAssertEqual(resolveEvent.events.count, 1)
        XCTAssertEqual(resolveEvent.events.first?.applyEvent.applyTime, applyTime)
    }

    func testCacheData_addEvent_prefilled() throws {
        var cacheData = try prefilledCacheData()
        cacheData.add(resolveToken: "token0", flagName: "flagName", applyTime: Date())
        cacheData.add(resolveToken: "token0", flagName: "flagName2", applyTime: Date())
        cacheData.add(resolveToken: "token0", flagName: "flagName3", applyTime: Date())

        XCTAssertEqual(cacheData.resolveEvents.first?.events.count, 6)
    }

    func testCacheData_addEvent_doesNotOverrideExisting() throws {
        let applyTime = Date(timeIntervalSince1970: 1000)
        var cacheData = CacheData(resolveToken: "token1", events: [])
        cacheData.add(resolveToken: "token1", flagName: "flagName", applyTime: applyTime)

        let applyTimeOther = Date(timeIntervalSince1970: 3000)
        cacheData.add(resolveToken: "token1", flagName: "flagName", applyTime: applyTimeOther)

        let applyEvent = try XCTUnwrap(cacheData.resolveEvents.first?.events.first)
        XCTAssertEqual(applyEvent.applyEvent.applyTime, applyTime)
    }

    func testCacheData_addEvent_multipleTokens() throws {
        var cacheData = try prefilledCacheData()
        let date = Date(timeIntervalSince1970: 2000)

        cacheData.add(resolveToken: "token1", flagName: "prefilled", applyTime: date)
        cacheData.add(resolveToken: "token2", flagName: "prefilled", applyTime: date)
        cacheData.add(resolveToken: "token3", flagName: "prefilled", applyTime: date)

        XCTAssertEqual(cacheData.resolveEvents.count, 4)
    }

    func testCacheData_removeEvent_prefilled() throws {
        let date = Date(timeIntervalSince1970: 2000)

        let event = FlagApply(name: "test-flag", applyTime: date)
        let event2 = FlagApply(name: "test-flag-2", applyTime: date)
        let event3 = FlagApply(name: "test-flag-3", applyTime: date)
        var cacheData = CacheData(resolveToken: "token", events: [event, event2, event3])

        XCTAssertEqual(cacheData.resolveEvents.first?.events.count, 3)

        cacheData.remove(resolveToken: "token", flagName: "test-flag")

        XCTAssertEqual(cacheData.resolveEvents.first?.events.count, 2)
    }

    func testCacheData_removesEmptyResolve() throws {
        var cacheData = try prefilledCacheData()
        cacheData.remove(resolveToken: "token0", flagName: "prefilled")
        cacheData.remove(resolveToken: "token0", flagName: "prefilled2")
        cacheData.remove(resolveToken: "token0", flagName: "prefilled3")

        XCTAssertEqual(cacheData.isEmpty, true)
    }

    func testCacheData_isEmpty() {
        let cacheData = CacheData.empty()
        XCTAssertEqual(cacheData.isEmpty, true)
    }

    func testCacheData_prefilledDataIsNotEmpty() throws {
        let cacheData = try prefilledCacheData()
        XCTAssertEqual(cacheData.isEmpty, false)
    }

    private func prefilledCacheData() throws -> CacheData {
        let date = Date(timeIntervalSince1970: 1000)
        let cacheData = CacheData(
            resolveToken: "token0",
            events: [
                FlagApply(name: "prefilled", applyTime: date),
                FlagApply(name: "prefilled2", applyTime: date),
                FlagApply(name: "prefilled3", applyTime: date)
            ]
        )

        return cacheData
    }
}
