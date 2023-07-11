import Foundation
import OpenFeature
import XCTest

@testable import ConfidenceProvider

@available(macOS 13.0, iOS 16.0, *)
class FlagApplierWithRetriesTest: XCTestCase {
    private let options = ConfidenceClientOptions(credentials: .clientSecret(secret: "test"))
    private var storage = StorageMock()
    private var httpClient = HttpClientMock()

    override func setUp() {
        storage = StorageMock()
        httpClient = HttpClientMock()

        super.setUp()
    }

    func testApply_differentTokens() async {
        // Given flag applier
        let applier = FlagApplierWithRetries(
            httpClient: httpClient, storage: storage, options: options, triggerBatch: false
        )

        // When 3 apply calls are issued with different tokens
        await applier.apply(flagName: "flag1", resolveToken: "token1")
        await applier.apply(flagName: "flag1", resolveToken: "token2")
        await applier.apply(flagName: "flag1", resolveToken: "token3")

        // Then http client sends 3 post requests
        XCTAssertEqual(httpClient.postCallCounter, 3)
    }

    func testApply_duplicateEventsAreNotSent() async {
        // Given flag applier
        let applier = FlagApplierWithRetries(
            httpClient: httpClient, storage: storage, options: options, triggerBatch: false
        )

        // When 3 identical apply calls are issued
        await applier.apply(flagName: "flag1", resolveToken: "token1")
        await applier.apply(flagName: "flag1", resolveToken: "token1")
        await applier.apply(flagName: "flag1", resolveToken: "token1")

        // Then http client sends only 1 post requests
        XCTAssertEqual(httpClient.postCallCounter, 1)
    }

    func testApply_differentFlags() async {
        // Given flag applier
        let applier = FlagApplierWithRetries(
            httpClient: httpClient, storage: storage, options: options, triggerBatch: false
        )

        // When 3 apply calls are issued with different flag names
        await applier.apply(flagName: "flag1", resolveToken: "token1")
        await applier.apply(flagName: "flag2", resolveToken: "token1")
        await applier.apply(flagName: "flag3", resolveToken: "token1")

        // Then http client sends only 3 post requests
        XCTAssertEqual(httpClient.postCallCounter, 3)
    }

    func testApply_doesNotstoreOnDisk() async throws {
        // Given flag applier
        let applier = FlagApplierWithRetries(
            httpClient: httpClient, storage: storage, options: options, triggerBatch: false
        )

        // When 3 apply calls are issued with different flag names
        await applier.apply(flagName: "flag1", resolveToken: "token1")
        await applier.apply(flagName: "flag2", resolveToken: "token1")
        await applier.apply(flagName: "flag3", resolveToken: "token1")

        // Then cache data is not stored on to the disk
        let storedData = try XCTUnwrap(storage.load(defaultValue: CacheData.empty()))
        XCTAssertEqual(storedData.resolveEvents.count, 0)
    }

    func testApply_emptyStorage_doesNotTriggerBatchApply() async throws {
        // Given flag applier with empty storage
        // When flag applier is initialised
        let task = Task {
            _ = FlagApplierWithRetries(
                httpClient: httpClient,
                storage: storage,
                options: options,
                triggerBatch: false
            )
        }
        await task.value

        // Then http client does not send apply flags batch request
        XCTAssertEqual(httpClient.postCallCounter, 0)
    }

    func testApply_previoslyStoredData_batchTriggered() async throws {
        // Given storage that has previously stored data (100 records, same token)
        let prefilledStorage = StorageMock()
        let prefilledCache = try CacheDataUtility.prefilledCacheData(applyEventCount: 100)
        try prefilledStorage.save(data: prefilledCache)

        let expectation = XCTestExpectation()
        httpClient.expectation = expectation

        // When flag applier is initialised
        let task = Task {
            _ = FlagApplierWithRetries(
                httpClient: httpClient,
                storage: prefilledStorage,
                options: options
            )
        }
        await task.value

        wait(for: [expectation], timeout: 5)

        // Then http client sends apply flags batch request, containing 100 records
        let request = try XCTUnwrap(httpClient.data?.first as? ApplyFlagsRequest)
        XCTAssertEqual(httpClient.postCallCounter, 1)
        XCTAssertEqual(request.flags.count, 100)
    }

    func testApply_multipleApplyCalls_batchTriggered() async throws {
        // Given flag applier with http client that is offline
        let httpClient = HttpClientMock(testMode: .error)
        let expectation = XCTestExpectation(description: "Waiting for batch trigger")
        expectation.expectedFulfillmentCount = 3
        httpClient.expectation = expectation

        let applier = FlagApplierWithRetries(
            httpClient: httpClient,
            storage: storage,
            options: options,
            triggerBatch: false
        )

        // When first apply call is issued
        // And http client request fails with .invalidResponse
        await applier.apply(flagName: "flag1", resolveToken: "token1")

        // And second apply call is issued
        // With test mode .success
        httpClient.testMode = .success
        await applier.apply(flagName: "flag2", resolveToken: "token1")

        wait(for: [expectation], timeout: 1)

        // Then 3 post calls are issued (one offline, one single apply, one batch request)
        XCTAssertEqual(httpClient.postCallCounter, 3)
        XCTAssertEqual(httpClient.data?.count, 3)

        let request1 = try XCTUnwrap(httpClient.data?[0] as? ApplyFlagsRequest)
        let request2 = try XCTUnwrap(httpClient.data?[1] as? ApplyFlagsRequest)
        let request3 = try XCTUnwrap(httpClient.data?[2] as? ApplyFlagsRequest)
        XCTAssertEqual(request1.flags.count, 1)
        XCTAssertEqual(request1.flags.first?.flag, "flags/flag1")
        XCTAssertEqual(request2.flags.count, 1)
        XCTAssertEqual(request2.flags.first?.flag, "flags/flag2")
        XCTAssertEqual(request3.flags.count, 1)
        XCTAssertEqual(request3.flags.first?.flag, "flags/flag1")
    }

    func testApply_multipleApplyCalls_sentSet() async throws {
        // Given flag applier with http client that is offline
        let cacheDataInteractor = CacheDataInteractor(storage: storage)
        let httpClient = HttpClientMock(testMode: .error)
        let expectation = XCTestExpectation(description: "Waiting for batch trigger")
        expectation.expectedFulfillmentCount = 3
        httpClient.expectation = expectation

        let applier = FlagApplierWithRetries(
            httpClient: httpClient,
            storage: storage,
            options: options,
            cacheDataInteractor: cacheDataInteractor,
            triggerBatch: false
        )

        // When first apply call is issued
        // And http client request fails with .invalidResponse
        await applier.apply(flagName: "flag1", resolveToken: "token1")

        // And second apply call is issued
        // With test mode .success
        httpClient.testMode = .success
        await applier.apply(flagName: "flag2", resolveToken: "token1")
        wait(for: [expectation], timeout: 1)

        Task {
            // Then both requests are marked as sent in cache data
            let cacheData = await cacheDataInteractor.cache
            let flagEvent1 = cacheData.flagEvent(resolveToken: "token1", name: "flag1")
            let flagEvent2 = cacheData.flagEvent(resolveToken: "token1", name: "flag2")

            XCTAssertEqual(flagEvent1?.applyEvent.sent, true)
            XCTAssertEqual(flagEvent2?.applyEvent.sent, true)
        }
    }

    func testApply_previoslyStoredData_cleanAfterSending() async throws {
        // Given storage that has previously stored data (100 records, same token)
        let prefilledStorage = StorageMock()
        let prefilledCache = try CacheDataUtility.prefilledCacheData(applyEventCount: 100)
        try prefilledStorage.save(data: prefilledCache)

        let expectation = XCTestExpectation(description: "Waiting for batch trigger")
        prefilledStorage.saveExpectation = expectation

        // When flag applier is initialised
        // And apply flags batch request is successful
        let task = Task {
            _ = FlagApplierWithRetries(
                httpClient: httpClient,
                storage: prefilledStorage,
                options: options
            )
        }
        await task.value

        wait(for: [expectation], timeout: 5)

        // Then storage has been cleaned
        let storedData = try prefilledStorage.load(defaultValue: CacheData.empty())
        XCTAssertEqual(httpClient.postCallCounter, 1)
        XCTAssertEqual(storedData.resolveEvents.count, 0)
    }

    func testApply_previoslyStoredData_doesNotCleanAfterSendingFailure() throws {
        // Given offline http client
        // And storage that has previosly stored data (100 records, same token)
        let offlineClient = HttpClientMock(testMode: .error)
        let prefilledStorage = StorageMock()
        let prefilledCache = try CacheDataUtility.prefilledCacheData(applyEventCount: 100)
        try prefilledStorage.save(data: prefilledCache)

        // When flag applier is initialised
        // And apply flags batch request fails with .invalidResponse
        _ = FlagApplierWithRetries(
            httpClient: offlineClient,
            storage: prefilledStorage,
            options: options,
            triggerBatch: false
        )

        // Then storage has not been cleaned and contains all 100 records
        let storedData = try prefilledStorage.load(defaultValue: CacheData.empty())
        XCTAssertEqual(storedData.resolveEvents.count, 1)
        XCTAssertEqual(storedData.resolveEvents[0].events.count, 100)
    }

    func testApplyOffline_storesOnDisk() async throws {
        // Given offline http client and flag applier
        let offlineClient = HttpClientMock(testMode: .error)
        let applier = FlagApplierWithRetries(
            httpClient: offlineClient, storage: storage, options: options, triggerBatch: false
        )

        // When 3 apply calls are issued with different flag names
        // And http client request fails with .invalidResponse
        await applier.apply(flagName: "flag1", resolveToken: "token1")
        await applier.apply(flagName: "flag2", resolveToken: "token1")
        await applier.apply(flagName: "flag3", resolveToken: "token1")

        // Then 1 resolve event record is written to disk
        let storedData = try XCTUnwrap(storage.load(defaultValue: CacheData.empty()))
        let data = try XCTUnwrap(storedData.resolveEvents.first { $0.resolveToken == "token1" })
        XCTAssertEqual(storedData.resolveEvents.count, 1)

        // And 3 flag event records are written to disk
        XCTAssertEqual(data.events.count, 3)
        let flag1 = data.events.first { $0.name == "flag1" }
        let flag2 = data.events.first { $0.name == "flag2" }
        let flag3 = data.events.first { $0.name == "flag3" }

        XCTAssertNotNil(flag1)
        XCTAssertNotNil(flag2)
        XCTAssertNotNil(flag3)
    }

    func testApplyOffline_storesOnDisk_multipleTokens() async throws {
        // Given offline http client and flag applier
        let offlineClient = HttpClientMock(testMode: .error)
        let applier = FlagApplierWithRetries(
            httpClient: offlineClient, storage: storage, options: options, triggerBatch: false
        )

        // When 3 apply calls are issued with different tokens
        // And http client request fails with .invalidResponse
        await applier.apply(flagName: "flag1", resolveToken: "token1")
        await applier.apply(flagName: "flag2", resolveToken: "token2")
        await applier.apply(flagName: "flag3", resolveToken: "token3")

        // Then 3 resolve event records are written to disk
        let storedData = try XCTUnwrap(storage.load(defaultValue: CacheData.empty()))
        XCTAssertEqual(storedData.resolveEvents.count, 3)

        // And 1 flag event record is written to each of them
        let token1 = storedData.resolveEvents.first { $0.resolveToken == "token1" }
        let token2 = storedData.resolveEvents.first { $0.resolveToken == "token2" }
        let token3 = storedData.resolveEvents.first { $0.resolveToken == "token3" }

        XCTAssertEqual(token1?.events.count, 1)
        XCTAssertEqual(token2?.events.count, 1)
        XCTAssertEqual(token3?.events.count, 1)
    }

    func testApplyOffline_previoslyStoredData_storesOnDisk() async throws {
        // Given flag applier set up with offline http client
        // And storage that has previously stored 1 record
        let offlineClient = HttpClientMock(testMode: .error)
        let prefilledStorage = StorageMock()
        let data = CacheData(resolveToken: "token0", flagName: "flag1", applyTime: Date(timeIntervalSince1970: 1000))
        try prefilledStorage.save(data: data)
        let applier = FlagApplierWithRetries(
            httpClient: offlineClient,
            storage: prefilledStorage,
            options: options,
            triggerBatch: false
        )

        // When new apply call is issued
        // And http client request fails with .invalidResponse
        await applier.apply(flagName: "flag1", resolveToken: "token1")

        // Then 2 resolve event records are stored on disk
        let storedData: CacheData = try XCTUnwrap(prefilledStorage.load(defaultValue: CacheData.empty()))
        XCTAssertEqual(storedData.resolveEvents.count, 2)

        // And added resolve event does not mutate
        let newResolveEvent = try XCTUnwrap(storedData.resolveEvents.first { $0.resolveToken == "token0" })
        XCTAssertEqual(newResolveEvent.events.count, 1)
        XCTAssertEqual(newResolveEvent.events[0].name, "flag1")
        XCTAssertEqual(newResolveEvent.events[0].applyEvent.applyTime, Date(timeIntervalSince1970: 1000))
        XCTAssertEqual(newResolveEvent.events[0].applyEvent.sent, false)
    }

    func testApplyOffline_previoslyStoredData_100records() async throws {
        // Given flag applier set up with offline http client
        // And storage that has previously stored 100 records with different tokens
        let offlineClient = HttpClientMock(testMode: .error)
        let prefilledStorage = StorageMock()
        let prefilledCache = try CacheDataUtility.prefilledCacheData(resolveEventCount: 100)
        try prefilledStorage.save(data: prefilledCache)
        let applier = FlagApplierWithRetries(
            httpClient: offlineClient,
            storage: prefilledStorage,
            options: options,
            triggerBatch: false
        )

        // When apply call is issued with another token
        // And http client request fails with .invalidResponse
        await applier.apply(flagName: "flag1", resolveToken: "token1")

        // Then 100 resolve event records are stored on disk
        let storedData: CacheData = try XCTUnwrap(prefilledStorage.load(defaultValue: CacheData.empty()))
        XCTAssertEqual(storedData.resolveEvents.count, 100)
    }

    func testApplyOffline_100applyCalls_sameToken() async throws {
        // Given flag applier set up with offline http client
        // And storage that has previously stored 100 records with same token
        let offlineClient = HttpClientMock(testMode: .error)
        let prefilledStorage = StorageMock()
        let prefilledCache = try CacheDataUtility.prefilledCacheData(applyEventCount: 100)
        try prefilledStorage.save(data: prefilledCache)
        let applier = FlagApplierWithRetries(
            httpClient: offlineClient,
            storage: prefilledStorage,
            options: options,
            triggerBatch: false
        )

        // When 100 apply calls are issued
        // And all http client requests fails with .invalidResponse
        await hundredApplyCalls(applier: applier, sameToken: true)

        // Then 1 resolve event record is stored on disk
        // And 200 flag event records are stored on disk
        let storedData: CacheData = try XCTUnwrap(prefilledStorage.load(defaultValue: CacheData.empty()))
        XCTAssertEqual(storedData.resolveEvents.count, 1)
        XCTAssertEqual(storedData.resolveEvents[0].events.count, 200)
    }

    private func hundredApplyCalls(applier: FlagApplier, sameToken: Bool = false) async {
        for _ in 0..<100 {
            let uuid = UUID()
            let token = sameToken ? "token0" : uuid.uuidString
            await applier.apply(flagName: uuid.uuidString, resolveToken: token)
        }
    }
}
