import Foundation
import OpenFeature
import XCTest

@testable import Confidence

final class CacheDataInteractorTests: XCTestCase {
    func testCacheDataInteractor_loadsEventsFromStorage() async throws {
        // Given prefilled storage with 10 resolve events (20 apply events in each)
        let prefilledCache = try CacheDataUtility.prefilledCacheData(
            resolveEventCount: 10,
            applyEventCount: 20
        )

        // When cache data interactor is initialised
        let cacheDataInteractor = CacheDataInteractor(cacheData: prefilledCache)

        // Then cache data is loaded from storage
        let cache = await cacheDataInteractor.cache
        XCTAssertEqual(cache.resolveEvents.count, 10)
        XCTAssertEqual(cache.resolveEvents.last?.events.count, 20)
    }

    func testCacheDataInteractor_addEventToEmptyCache() async throws {
        // Given cache data interactor with no previously stored data
        let cacheDataInteractor = CacheDataInteractor(cacheData: .empty())

        let cache = await cacheDataInteractor.cache
        XCTAssertEqual(cache.resolveEvents.count, 0)


        // When cache data add method is called
        _ = await cacheDataInteractor.add(resolveToken: "token", flagName: "name", applyTime: Date())

        // Then event is added with
        let cache2 = await cacheDataInteractor.cache
        XCTAssertEqual(cache2.resolveEvents.count, 1)
    }

    func testCacheDataInteractor_addEventToPreFilledCache() async throws {
        // Given cache data interactor with previously stored data (1 resolve token and 2 apply event)
        let prefilledCacheData = try CacheDataUtility.prefilledCacheData(applyEventCount: 2)
        let cacheDataInteractor = CacheDataInteractor(cacheData: prefilledCacheData)

        // When cache data add method is called
        _ = await cacheDataInteractor.add(resolveToken: "token", flagName: "name", applyTime: Date())

        // Then event is added with
        let cache = await cacheDataInteractor.cache
        XCTAssertEqual(cache.resolveEvents.count, 2)
    }
}
