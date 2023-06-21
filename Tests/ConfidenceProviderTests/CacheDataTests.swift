import Foundation
import OpenFeature
import XCTest

@testable import ConfidenceProvider

final class CacheDataTests: XCTestCase {

    func testCacheData_addEvent_emptyCache() {
        var cacheData = CacheData(data: [:])
        cacheData.addEvent(resolveToken: "token1", flagName: "flagName", applyTime: Date())

        XCTAssertEqual(cacheData.data.count, 1)
        XCTAssertNotNil(cacheData.data["token1"]?.data["flagName"])
    }

    func testCacheData_addEvent_prefilled() throws {
        var cacheData = try prefilledCacheData()
        cacheData.addEvent(resolveToken: "token1", flagName: "flagName", applyTime: Date())
        cacheData.addEvent(resolveToken: "token1", flagName: "flagName2", applyTime: Date())
        cacheData.addEvent(resolveToken: "token1", flagName: "flagName3", applyTime: Date())

        XCTAssertEqual(cacheData.data.count, 2)
        XCTAssertEqual(cacheData.data["token0"]?.data.count, 3)
        XCTAssertEqual(cacheData.data["token1"]?.data.count, 3)
    }

    func testCacheData_addEvent_exists() throws {
        var cacheData = try prefilledCacheData()
        let date = Date(timeIntervalSince1970: 2000)

        cacheData.addEvent(resolveToken: "token0", flagName: "prefilled", applyTime: date)
        cacheData.addEvent(resolveToken: "token0", flagName: "prefilled2", applyTime: date)

        XCTAssertEqual(cacheData.data.count, 1)
        XCTAssertEqual(cacheData.data["token0"]?.data.count, 3)
        XCTAssertEqual(cacheData.data["token0"]?.data["prefilled"]?.count, 2)
        XCTAssertEqual(cacheData.data["token0"]?.data["prefilled2"]?.count, 2)
        XCTAssertEqual(cacheData.data["token0"]?.data["prefilled3"]?.count, 1)
    }

    func testCacheData_isEmpty() {
        let cacheData = CacheData(data: [:])
        XCTAssertEqual(cacheData.data.isEmpty, true)
    }

    func testCacheData_flagEventsIsEmpty() {
        let emptyFlagEvents = FlagEvents(data: ["flagName": [:]])
        let cacheData = CacheData(data: ["token": emptyFlagEvents])
        XCTAssertEqual(cacheData.isEmpty, true)
    }

    func testCacheData_flagEventsIsNotEmpty() {
        var cacheData = CacheData(data: [:])
        cacheData.addEvent(resolveToken: "token1", flagName: "flagName", applyTime: Date())
        XCTAssertEqual(cacheData.isEmpty, false)
    }

    func testCacheData_prefilledDataIsNotEmpty() throws {
        let cacheData = try prefilledCacheData()
        XCTAssertEqual(cacheData.isEmpty, false)
    }

    private func prefilledCacheData() throws -> CacheData {
        let uuid = try XCTUnwrap(UUID(uuidString: "F7851150-8276-4981-8F97-E64986380B6D"))
        let date = Date(timeIntervalSince1970: 1000)
        let flagEvents = FlagEvents(data: [
            "prefilled": [uuid: date],
            "prefilled2": [uuid: date],
            "prefilled3": [uuid: date]
        ])

        let cacheData = CacheData(data: ["token0": flagEvents])
        return cacheData
    }

}
