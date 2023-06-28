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
        XCTAssertEqual(resolveEvent.events.first?.applyEvents.first?.applyTime, applyTime)
    }

    func testCacheData_addEvent_prefilled() throws {
        var cacheData = try prefilledCacheData()
        cacheData.add(resolveToken: "token0", flagName: "flagName", applyTime: Date())
        cacheData.add(resolveToken: "token0", flagName: "flagName2", applyTime: Date())
        cacheData.add(resolveToken: "token0", flagName: "flagName3", applyTime: Date())

        XCTAssertEqual(cacheData.resolveEvents.first?.events.count, 6)
    }

    func testCacheData_addEvent_exists() throws {
        var cacheData = try prefilledCacheData()
        let date = Date(timeIntervalSince1970: 2000)

        cacheData.add(resolveToken: "token0", flagName: "prefilled", applyTime: date)

        let index = try XCTUnwrap(cacheData.resolveEvents.first?.events.firstIndex { $0.name == "prefilled" })
        XCTAssertEqual(cacheData.resolveEvents.first?.events.count, 3)
        XCTAssertEqual(cacheData.resolveEvents.first?.events[index].applyEvents.count, 2)
    }

    func testCacheData_addEvent_multipleTokens() throws {
        var cacheData = try prefilledCacheData()
        let date = Date(timeIntervalSince1970: 2000)

        cacheData.add(resolveToken: "token1", flagName: "prefilled", applyTime: date)
        cacheData.add(resolveToken: "token2", flagName: "prefilled", applyTime: date)
        cacheData.add(resolveToken: "token3", flagName: "prefilled", applyTime: date)

        XCTAssertEqual(cacheData.resolveEvents.count, 4)
    }

    func testCacheData_removeEvent_exists() throws {
        let uuid = try XCTUnwrap(UUID(uuidString: "F7851150-8276-4981-8F97-E64986380B6D"))
        let date = Date(timeIntervalSince1970: 2000)

        let event = FlagEvent(name: "test-flag", applyTime: date, uuid: uuid)
        var cacheData = CacheData(resolveToken: "token", events: [event])

        XCTAssertEqual(cacheData.resolveEvents.first?.events.count, 1)

        cacheData.remove(resolveToken: "token", flagName: "test-flag", uuid: uuid)

        XCTAssertEqual(cacheData.resolveEvents.first?.events.count, 0)
    }

    func testCacheData_removeEvent_prefilled() throws {
        let uuid = try XCTUnwrap(UUID(uuidString: "F7851150-8276-4981-8F97-E64986380B6D"))
        let date = Date(timeIntervalSince1970: 2000)

        let event = FlagEvent(name: "test-flag", applyTime: date, uuid: uuid)
        let event2 = FlagEvent(name: "test-flag-2", applyTime: date)
        let event3 = FlagEvent(name: "test-flag-3", applyTime: date)
        var cacheData = CacheData(resolveToken: "token", events: [event, event2, event3])

        XCTAssertEqual(cacheData.resolveEvents.first?.events.count, 3)

        cacheData.remove(resolveToken: "token", flagName: "test-flag", uuid: uuid)

        XCTAssertEqual(cacheData.resolveEvents.first?.events.count, 2)
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
        let uuid = try XCTUnwrap(UUID(uuidString: "F7851150-8276-4981-8F97-E64986380B6D"))
        let date = Date(timeIntervalSince1970: 1000)
        let cacheData = CacheData(
            resolveToken: "token0",
            events: [
                FlagEvent(name: "prefilled", applyTime: date, uuid: uuid),
                FlagEvent(name: "prefilled2", applyTime: date, uuid: uuid),
                FlagEvent(name: "prefilled3", applyTime: date, uuid: uuid)
            ]
        )

        return cacheData
    }
}
