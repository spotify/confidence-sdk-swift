import Foundation
import OpenFeature
import XCTest

@testable import Confidence

final class CacheDataTests: XCTestCase {
    func testCacheData_addEvent_emptyCache() throws {
        // Given empty cache data
        var cacheData = CacheData.empty()

        // When add event is called
        let applyTime = Date()
        _ = cacheData.add(resolveToken: "token1", flagName: "flagName", applyTime: applyTime)

        // Then cache data has one resolve event
        XCTAssertEqual(cacheData.resolveEvents.count, 1)

        // And resolve event token and apply event is set correctly
        let resolveEvent = try XCTUnwrap(cacheData.resolveEvents.first)
        XCTAssertEqual(resolveEvent.resolveToken, "token1")
        XCTAssertEqual(resolveEvent.events.count, 1)
        XCTAssertEqual(resolveEvent.events.first?.applyTime, applyTime)
    }

    func testCacheData_addEvent_emptyFlagEvents() throws {
        // Given cache data with empty flag events
        let applyTime = Date()
        var cacheData = CacheData(resolveToken: "token1", events: [])

        // When add event is called with token that already exist in cache data
        _ = cacheData.add(resolveToken: "token1", flagName: "flagName", applyTime: applyTime)

        // Then cache data has one resolve event
        XCTAssertEqual(cacheData.resolveEvents.count, 1)

        // And resolve event token and apply event is set correctly
        let resolveEvent = try XCTUnwrap(cacheData.resolveEvents.first)
        XCTAssertEqual(resolveEvent.resolveToken, "token1")
        XCTAssertEqual(resolveEvent.events.count, 1)
        XCTAssertEqual(resolveEvent.events.first?.applyTime, applyTime)
    }

    func testCacheData_addEvent_prefilled() throws {
        // Given pre filled cache data
        var cacheData = try CacheDataUtility.prefilledCacheData()

        // When add event is called 3 times with token that already exist in cache data
        _ = cacheData.add(resolveToken: "token0", flagName: "flagName", applyTime: Date())
        _ = cacheData.add(resolveToken: "token0", flagName: "flagName2", applyTime: Date())
        _ = cacheData.add(resolveToken: "token0", flagName: "flagName3", applyTime: Date())

        // Then cache data has 6 apply events
        XCTAssertEqual(cacheData.resolveEvents.first?.events.count, 6)
    }

    func testCacheData_addEvent_doesNotOverrideExisting() throws {
        // Given pre filled cache data
        let applyTime = Date(timeIntervalSince1970: 1000)
        var cacheData = CacheData(resolveToken: "token1", events: [])
        _ = cacheData.add(resolveToken: "token1", flagName: "flagName", applyTime: applyTime)

        // When add event is called with token and flagName that already exist in cache
        let applyTimeOther = Date(timeIntervalSince1970: 3000)
        _ = cacheData.add(resolveToken: "token1", flagName: "flagName", applyTime: applyTimeOther)

        // Then apply record is not overriden
        let applyEvent = try XCTUnwrap(cacheData.resolveEvents.first?.events.first)
        XCTAssertEqual(applyEvent.applyTime, applyTime)
    }

    func testCacheData_addEvent_multipleTokens() throws {
        // Given pre filled cache data
        var cacheData = try CacheDataUtility.prefilledCacheData()
        let date = Date(timeIntervalSince1970: 2000)

        // When add event is called 3 times with different tokens
        _ = cacheData.add(resolveToken: "token1", flagName: "prefilled", applyTime: date)
        _ = cacheData.add(resolveToken: "token2", flagName: "prefilled", applyTime: date)
        _ = cacheData.add(resolveToken: "token3", flagName: "prefilled", applyTime: date)

        // Then cache data has 4 resolve event
        XCTAssertEqual(cacheData.resolveEvents.count, 4)
    }

    func testCacheData_removeEvent_prefilled() throws {
        // Given pre filled cache data
        let date = Date(timeIntervalSince1970: 2000)
        let event = FlagApply(name: "test-flag", applyTime: date)
        let event2 = FlagApply(name: "test-flag-2", applyTime: date)
        let event3 = FlagApply(name: "test-flag-3", applyTime: date)
        var cacheData = CacheData(resolveToken: "token", events: [event, event2, event3])

        // When remove event is called for token and flag that exists in the cache
        cacheData.remove(resolveToken: "token", flagName: "test-flag")

        // Then cache data has 2 resolve event lef
        XCTAssertEqual(cacheData.resolveEvents.first?.events.count, 2)
    }

    func testCacheData_removesEmptyResolve() throws {
        // Given prefilled cached data
        var cacheData = try CacheDataUtility.prefilledCacheData()

        // When remove event is called for all items that exists in cache
        cacheData.remove(resolveToken: "token0", flagName: "prefilled0")
        cacheData.remove(resolveToken: "token0", flagName: "prefilled1")
        cacheData.remove(resolveToken: "token0", flagName: "prefilled2")

        // Then resolveEvents isEmpty
        XCTAssertEqual(cacheData.resolveEvents.isEmpty, true)
    }

    func testCacheData_eventExist_isEventSent() throws {
        // Given prefilled cached data
        // and all apply events has sent property set to false
        var cacheData = try CacheDataUtility.prefilledCacheData()
        let resolve = try XCTUnwrap(cacheData.resolveEvents.first)
        let sentEvents = resolve.events.filter { $0.status == .sent }
        XCTAssertEqual(sentEvents.count, 0)

        // When set event sent is called for item that exists in cache
        cacheData.setEventStatus(resolveToken: "token0", name: "prefilled2")
        let resolveAfterUpdate = try XCTUnwrap(cacheData.resolveEvents.first)

        // Then apply event sent property has been set to true
        let sentEventsAfterUpdate = resolveAfterUpdate.events.filter { $0.status == .sent }
        XCTAssertEqual(sentEventsAfterUpdate.count, 1)
        XCTAssertEqual(sentEventsAfterUpdate.first?.name, "prefilled2")
    }

    func testCacheData_eventDoesNotExist_isEventSent() throws {
        // Given prefilled cached data
        // and all apply events has sent property set to false
        var cacheData = try CacheDataUtility.prefilledCacheData()
        let resolve = try XCTUnwrap(cacheData.resolveEvents.first)
        let sentEvents = resolve.events.filter { $0.status == .sent }
        XCTAssertEqual(sentEvents.count, 0)

        // When set event sent is called for item that does not exists in cache
        cacheData.setEventStatus(resolveToken: "token0", name: "prefilled45")
        let resolveAfterUpdate = try XCTUnwrap(cacheData.resolveEvents.first)

        // Then apply event sent property has not been changed
        let sentEventsAfterUpdate = resolveAfterUpdate.events.filter { $0.status == .sent }
        XCTAssertEqual(sentEventsAfterUpdate.count, 0)
    }

    func testCacheData_isEmpty() {
        // Given empty cached data
        let cacheData = CacheData.empty()

        // Then cache data isEmpty property is true
        XCTAssertEqual(cacheData.isEmpty, true)
    }

    func testCacheData_emptyEvents_isEmpty() {
        // Given cached data with empty flag events
        let cacheData = CacheData(resolveToken: "token", events: [])

        // Then cache data isEmpty property is true
        XCTAssertEqual(cacheData.isEmpty, true)
    }

    func testCacheData_prefilledDataIsNotEmpty() throws {
        // Given prefilled cached data
        let cacheData = try CacheDataUtility.prefilledCacheData()

        // Then cache data isEmpty property is false
        XCTAssertEqual(cacheData.isEmpty, false)
    }
}
