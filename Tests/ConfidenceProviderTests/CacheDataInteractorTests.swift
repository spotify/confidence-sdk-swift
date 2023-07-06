import Foundation
import OpenFeature
import XCTest

@testable import ConfidenceProvider

final class CacheDataInteractorTests: XCTestCase {
    func testCacheDataInteractor_loadsEventsFromStorage() throws {
        // Given prefilled storage with 10 resolve events (20 apply events in each)
        let prefilledCache = try CacheDataUtility.prefilledCacheData(
            resolveEventCount: 10,
            applyEventCount: 20
        )
        let prefilledStorage = try StorageMock(data: prefilledCache)

        // When cache data interactor is initialised
        let cacheDataInteractor = CacheDataInteractor(storage: prefilledStorage)

        // Then cache data is loaded from storage
        Task {
            // Wrapped it in the Task in order to ensure that async code is completed before assertions
            let cache = await cacheDataInteractor.cache
            XCTAssertEqual(cache.resolveEvents.count, 10)
            XCTAssertEqual(cache.resolveEvents.last?.events.count, 20)
        }
    }

    func testCacheDataInteractor_addEventToEmptyCache() async throws {
        // Given cache data interactor with no previously stored data
        let storage = StorageMock()
        let cacheDataInteractor = CacheDataInteractor(storage: storage)
        Task {
            let cache = await cacheDataInteractor.cache
            XCTAssertEqual(cache.resolveEvents.count, 0)
        }

        Task {
            // When cache data add method is called
            await cacheDataInteractor.add(resolveToken: "token", flagName: "name", applyTime: Date())

            // Then event is added with
            let cache = await cacheDataInteractor.cache
            XCTAssertEqual(cache.resolveEvents.count, 1)
        }
    }

    func testCacheDataInteractor_addEventToPreFilledCache() async throws {
        // Given cache data interactor with previously stored data (1 resolve token and 2 apply event)
        let prefilledCacheData = try CacheDataUtility.prefilledCacheData(applyEventCount: 2)
        let prefilledStorage = try StorageMock(data: prefilledCacheData)
        let cacheDataInteractor = CacheDataInteractor(storage: prefilledStorage)

        Task {
            // When cache data add method is called
            await cacheDataInteractor.add(resolveToken: "token", flagName: "name", applyTime: Date())

            // Then event is added with
            let cache = await cacheDataInteractor.cache
            XCTAssertEqual(cache.resolveEvents.count, 2)
        }
    }
}
