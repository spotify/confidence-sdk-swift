// swiftlint:disable type_body_length
// swiftlint:disable file_length
import Foundation
import OpenFeature
import XCTest

@testable import Confidence

@available(macOS 13.0, iOS 16.0, *)
class FlagApplierWithRetriesTest: XCTestCase {
    private let options = ConfidenceClientOptions(credentials: .clientSecret(secret: "test"))
    private var storage = StorageMock()
    private var httpClient = HttpClientMock()
    private let metadata = ConfidenceMetadata(name: "test-provider-name", version: "0.0.0.")

    override func setUp() {
        storage = StorageMock()
        httpClient = HttpClientMock()

        super.setUp()
    }

    func testApply_differentTokens() async {
        // Given flag applier
        let applier = FlagApplierWithRetries(
            httpClient: httpClient, storage: storage, options: options, metadata: metadata, triggerBatch: false
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
            httpClient: httpClient, storage: storage, options: options, metadata: metadata, triggerBatch: false
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
        let cacheDataInteractor = CacheDataInteractor(cacheData: .empty())
        let applier = FlagApplierWithRetries(
            httpClient: httpClient,
            storage: storage,
            options: options,
            metadata: metadata,
            cacheDataInteractor: cacheDataInteractor,
            triggerBatch: false
        )

        // When 3 apply calls are issued with different flag names
        await applier.apply(flagName: "flag1", resolveToken: "token1")
        await applier.apply(flagName: "flag2", resolveToken: "token1")
        await applier.apply(flagName: "flag3", resolveToken: "token1")

        let cacheData = await cacheDataInteractor.cache

        // Then http client sends 3 post requests
        XCTAssertEqual(httpClient.postCallCounter, 3)
        XCTAssertEqual(cacheData.resolveEvents.count, 1)
        XCTAssertEqual(cacheData.resolveEvents[0].events.count, 3)
    }

    func testApply_doesNotStoreOnDisk() async throws {
        // Given flag applier
        let cacheDataInteractor = CacheDataInteractor(cacheData: .empty())
        let applier = FlagApplierWithRetries(
            httpClient: httpClient,
            storage: storage,
            options: options,
            metadata: metadata,
            cacheDataInteractor: cacheDataInteractor,
            triggerBatch: false
        )

        let networkExpectation = self.expectation(description: "Waiting for network call to complete")
        networkExpectation.expectedFulfillmentCount = 3
        httpClient.expectation = networkExpectation

        // When 3 apply calls are issued with different flag names
        await applier.apply(flagName: "flag1", resolveToken: "token1")
        await applier.apply(flagName: "flag2", resolveToken: "token1")
        await applier.apply(flagName: "flag3", resolveToken: "token1")

        await waitForExpectations(timeout: 1.0)

        // Then cache data is not stored on to the disk
        // But stored in the local cache as sent
        let cacheData = await cacheDataInteractor.cache
        XCTAssertEqual(cacheData.resolveEvents.count, 1)
        XCTAssertEqual(cacheData.resolveEvents[0].events.count, 3)
        XCTAssertTrue(cacheData.resolveEvents[0].events.allSatisfy { $0.status == .sent })

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
                metadata: metadata,
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

        let expectation = self.expectation(description: "Waiting for network call to complete")
        expectation.expectedFulfillmentCount = 5
        httpClient.expectation = expectation

        let storageExpectation = self.expectation(description: "Waiting for storage expectation to be completed")
        storageExpectation.expectedFulfillmentCount = 10
        prefilledStorage.saveExpectation = storageExpectation

        // When flag applier is initialised
        _ = FlagApplierWithRetries(
            httpClient: httpClient,
            storage: prefilledStorage,
            options: options,
            metadata: metadata
        )

        await waitForExpectations(timeout: 5.0)

        // Then http client sends 5 apply flag batch request, containing 20 records each
        let request = try XCTUnwrap(httpClient.data?.first as? ApplyFlagsRequest)
        XCTAssertEqual(httpClient.postCallCounter, 5)
        XCTAssertEqual(request.flags.count, 20)
    }

    func test_previoslyStoredInTransitData_batchTriggered() async throws {
        // Given storage that has previously stored data (100 records, same token)
        let prefilledStorage = StorageMock()
        var prefilledCache = try CacheDataUtility.prefilledCacheData(applyEventCount: 100)
        // Set all the events in the cache/storage as in-transit, i.e. `sending`
        prefilledCache.setEventStatus(resolveToken: "token0", status: .sending)
        try prefilledStorage.save(data: prefilledCache)

        let expectation = self.expectation(description: "Waiting for network call to complete")
        expectation.expectedFulfillmentCount = 5
        httpClient.expectation = expectation

        let storageExpectation = self.expectation(description: "Waiting for storage expectation to be completed")
        storageExpectation.expectedFulfillmentCount = 10
        prefilledStorage.saveExpectation = storageExpectation

        // When flag applier is initialised
        _ = FlagApplierWithRetries(
            httpClient: httpClient,
            storage: prefilledStorage,
            options: options,
            metadata: metadata
        )

        await waitForExpectations(timeout: 5.0)

        // Then http client sends 5 apply flag batch request, containing 20 records each
        let request = try XCTUnwrap(httpClient.data?.first as? ApplyFlagsRequest)
        XCTAssertEqual(httpClient.postCallCounter, 5)
        XCTAssertEqual(request.flags.count, 20)
    }

    func testApply_previoslyStoredData_partialFailure() async throws {
        // Given storage that has previously stored data (100 records, same token)
        let partiallyFailingHttpClient = HttpClientMock(testMode: .failFirstChunk)
        let prefilledStorage = StorageMock()
        let prefilledCache = try CacheDataUtility.prefilledCacheData(applyEventCount: 100)
        try prefilledStorage.save(data: prefilledCache)

        let expectation = self.expectation(description: "Waiting for network call to complete")
        expectation.expectedFulfillmentCount = 5
        partiallyFailingHttpClient.expectation = expectation

        let storageExpectation = self.expectation(description: "Waiting for storage expectation to be completed")
        storageExpectation.expectedFulfillmentCount = 10
        prefilledStorage.saveExpectation = storageExpectation

        // When flag applier is initialised
        _ = FlagApplierWithRetries(
            httpClient: partiallyFailingHttpClient,
            storage: prefilledStorage,
            options: options,
            metadata: metadata
        )

        await waitForExpectations(timeout: 5.0)

        // Then http client sends 5 apply flags batch request, containing 20 records each
        let request = try XCTUnwrap(partiallyFailingHttpClient.data?.first as? ApplyFlagsRequest)
        XCTAssertEqual(partiallyFailingHttpClient.postCallCounter, 5)
        XCTAssertEqual(request.flags.count, 20)

        // And storage has 20 failed events saved
        let storedData = try prefilledStorage.load(defaultValue: CacheData.empty())
        XCTAssertEqual(storedData.resolveEvents.count, 1)

        let unsent = try XCTUnwrap(storedData.resolveEvents.first?.events.filter { $0.status == .created })
        XCTAssertEqual(unsent.count, 20)
    }

    func testApply_multipleApplyCalls_batchTriggered() async throws {
        // Given flag applier with http client that is offline
        let httpClient = HttpClientMock(testMode: .offline)
        let networkExpectation = self.expectation(description: "Waiting for batch trigger")
        networkExpectation.expectedFulfillmentCount = 2
        httpClient.expectation = networkExpectation

        let applier = FlagApplierWithRetries(
            httpClient: httpClient,
            storage: storage,
            options: options,
            metadata: metadata,
            triggerBatch: false
        )

        // When first apply call is issued
        // And http client request fails with .invalidResponse
        await applier.apply(flagName: "flag1", resolveToken: "token1")

        // And second apply call is issued
        // With test mode .success
        httpClient.testMode = .success
        await applier.apply(flagName: "flag2", resolveToken: "token1")

        await waitForExpectations(timeout: 1.0)

        // Then 3 post calls are issued (one offline, one batch apply containing 2 reconrds)
        XCTAssertEqual(httpClient.postCallCounter, 2)
        XCTAssertEqual(httpClient.data?.count, 2)

        let request1 = try XCTUnwrap(httpClient.data?[0] as? ApplyFlagsRequest)
        let request2 = try XCTUnwrap(httpClient.data?[1] as? ApplyFlagsRequest)
        XCTAssertEqual(request1.flags.count, 1)
        XCTAssertEqual(request1.flags.first?.flag, "flags/flag1")
        XCTAssertEqual(request2.flags.count, 2)
        XCTAssertEqual(request2.flags.first?.flag, "flags/flag1")
        XCTAssertEqual(request2.flags.last?.flag, "flags/flag2")
    }

    func testApply_multipleApplyCalls_sentSet() async throws {
        // Given flag applier with http client that is offline
        let cacheDataInteractor = CacheDataInteractor(cacheData: .empty())
        let offlineClient = HttpClientMock(testMode: .offline)
        let networkExpectation = self.expectation(description: "Waiting for network call to complete")
        networkExpectation.expectedFulfillmentCount = 2
        offlineClient.expectation = networkExpectation

        let storageExpectation = self.expectation(description: "Waiting for storage expectation to be completed")
        storageExpectation.expectedFulfillmentCount = 6
        storage.saveExpectation = storageExpectation

        let applier = FlagApplierWithRetries(
            httpClient: offlineClient,
            storage: storage,
            options: options,
            metadata: metadata,
            cacheDataInteractor: cacheDataInteractor,
            triggerBatch: false
        )

        // When first apply call is issued
        // And http client request fails with .invalidResponse
        await applier.apply(flagName: "flag1", resolveToken: "token1")

        // And second apply call is issued
        // With test mode .success
        offlineClient.testMode = .success
        await applier.apply(flagName: "flag2", resolveToken: "token1")
        await waitForExpectations(timeout: 1.0)

        // Then both requests are marked as sent in cache data
        let cacheData = await cacheDataInteractor.cache
        let flagEvent1 = cacheData.flagEvent(resolveToken: "token1", name: "flag1")
        let flagEvent2 = cacheData.flagEvent(resolveToken: "token1", name: "flag2")

        XCTAssertEqual(flagEvent1?.status, .sent)
        XCTAssertEqual(flagEvent2?.status, .sent)
    }

    func testApply_previoslyStoredData_cleanAfterSending() async throws {
        // Given storage that has previously stored data (100 records, same token)
        let prefilledStorage = StorageMock()
        let prefilledCache = try CacheDataUtility.prefilledCacheData(applyEventCount: 100)
        try prefilledStorage.save(data: prefilledCache)

        let storageExpectation = self.expectation(description: "Waiting for storage expectation to be completed")
        storageExpectation.expectedFulfillmentCount = 10
        prefilledStorage.saveExpectation = storageExpectation

        let networkExpectation = self.expectation(description: "Waiting for networkRequest to be completed")
        networkExpectation.expectedFulfillmentCount = 5
        httpClient.expectation = networkExpectation

        // When flag applier is initialised
        // And apply flags batch request is successful
        _ = FlagApplierWithRetries(
            httpClient: httpClient,
            storage: prefilledStorage,
            options: options,
            metadata: metadata
        )

        await waitForExpectations(timeout: 1.0)

        // Then storage has been cleaned
        let storedData = try prefilledStorage.load(defaultValue: CacheData.empty())
        XCTAssertEqual(httpClient.postCallCounter, 5)
        XCTAssertEqual(storedData.resolveEvents.count, 0)
    }

    func testApply_100applyCalls_sameToken() async throws {
        // Given flag applier set up with offline http client
        // And storage that has previously stored 100 records with same token
        let networkExpectation = self.expectation(description: "Waiting for networkRequest to be completed")
        networkExpectation.expectedFulfillmentCount = 105
        httpClient.expectation = networkExpectation

        let prefilledStorage = StorageMock()
        let prefilledCache = try CacheDataUtility.prefilledCacheData(applyEventCount: 100)
        try prefilledStorage.save(data: prefilledCache)
        let applier = FlagApplierWithRetries(
            httpClient: httpClient,
            storage: prefilledStorage,
            options: options,
            metadata: metadata,
            triggerBatch: false
        )

        // When 100 apply calls are issued
        // And all http client requests fails with .invalidResponse
        await hundredApplyCalls(applier: applier, sameToken: true)
        await waitForExpectations(timeout: 1.0)

        // Then strored data is empty
        let storedData: CacheData = try XCTUnwrap(prefilledStorage.load(defaultValue: CacheData.empty()))
        XCTAssertEqual(storedData.resolveEvents.count, 0)
    }

    func testApply_previoslyStoredData_doesNotCleanAfterSendingFailure() throws {
        // Given offline http client
        // And storage that has previosly stored data (100 records, same token)
        let offlineClient = HttpClientMock(testMode: .offline)
        let prefilledStorage = StorageMock()
        let prefilledCache = try CacheDataUtility.prefilledCacheData(applyEventCount: 100)
        try prefilledStorage.save(data: prefilledCache)

        // When flag applier is initialised
        // And apply flags batch request fails with .invalidResponse
        _ = FlagApplierWithRetries(
            httpClient: offlineClient,
            storage: prefilledStorage,
            options: options,
            metadata: metadata,
            triggerBatch: false
        )

        // Then storage has not been cleaned and contains all 100 records
        let storedData = try prefilledStorage.load(defaultValue: CacheData.empty())
        XCTAssertEqual(storedData.resolveEvents.count, 1)
        XCTAssertEqual(storedData.resolveEvents[0].events.count, 100)
    }

    func testApplyOffline_storesOnDisk() async throws {
        // Given offline http client and flag applier
        let offlineClient = HttpClientMock(testMode: .offline)
        let applier = FlagApplierWithRetries(
            httpClient: offlineClient, storage: storage, options: options, metadata: metadata, triggerBatch: false
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
        let offlineClient = HttpClientMock(testMode: .offline)
        let applier = FlagApplierWithRetries(
            httpClient: offlineClient, storage: storage, options: options, metadata: metadata, triggerBatch: false
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
        let offlineClient = HttpClientMock(testMode: .offline)
        let data = CacheData(resolveToken: "token0", flagName: "flag1", applyTime: Date(timeIntervalSince1970: 1000))
        let prefilledStorage = try StorageMock(data: data)

        let networkExpectation = self.expectation(description: "Waiting for networkRequest to be completed")
        networkExpectation.expectedFulfillmentCount = 2
        offlineClient.expectation = networkExpectation

        let applier = FlagApplierWithRetries(
            httpClient: offlineClient,
            storage: prefilledStorage,
            options: options,
            metadata: metadata,
            triggerBatch: false
        )

        // When new apply call is issued
        // And http client request fails with .invalidResponse
        await applier.apply(flagName: "flag1", resolveToken: "token1")

        await waitForExpectations(timeout: 5.0)

        // Then 2 resolve event records are stored on disk
        let storedData: CacheData = try XCTUnwrap(prefilledStorage.load(defaultValue: CacheData.empty()))
        XCTAssertEqual(storedData.resolveEvents.count, 2)

        // And added resolve event does not mutate
        let newResolveEvent = try XCTUnwrap(storedData.resolveEvents.first { $0.resolveToken == "token0" })
        XCTAssertEqual(newResolveEvent.events.count, 1)
        XCTAssertEqual(newResolveEvent.events[0].name, "flag1")
        XCTAssertEqual(newResolveEvent.events[0].applyTime, Date(timeIntervalSince1970: 1000))
        XCTAssertEqual(newResolveEvent.events[0].status, .created)
    }

    func testApplyOffline_previoslyStoredData_100records() async throws {
        // Given flag applier set up with offline http client
        // And storage that has previously stored 100 records with different tokens
        let offlineClient = HttpClientMock(testMode: .offline)
        let prefilledStorage = StorageMock()
        let prefilledCache = try CacheDataUtility.prefilledCacheData(resolveEventCount: 100)
        try prefilledStorage.save(data: prefilledCache)
        let applier = FlagApplierWithRetries(
            httpClient: offlineClient,
            storage: prefilledStorage,
            options: options,
            metadata: metadata,
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
        let offlineClient = HttpClientMock(testMode: .offline)
        let networkExpectation = self.expectation(description: "Waiting for networkRequest to be completed")

        // Since we don't fail other requests when one request is failing
        // This setup gives us 800 network calls
        // Every request is split in 6 to 10 batches (from 101 - 200 apply events)
        networkExpectation.expectedFulfillmentCount = 800
        offlineClient.expectation = networkExpectation

        let prefilledStorage = StorageMock()
        let prefilledCache = try CacheDataUtility.prefilledCacheData(applyEventCount: 100)
        try prefilledStorage.save(data: prefilledCache)
        let applier = FlagApplierWithRetries(
            httpClient: offlineClient,
            storage: prefilledStorage,
            options: options,
            metadata: metadata,
            triggerBatch: false
        )

        // When 100 apply calls are issued
        // And all http client requests fails with .invalidResponse
        await hundredApplyCalls(applier: applier, sameToken: true)
        await waitForExpectations(timeout: 1.0)

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
