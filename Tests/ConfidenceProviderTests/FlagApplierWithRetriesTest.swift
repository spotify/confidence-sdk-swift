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
        let applier = FlagApplierWithRetries(httpClient: httpClient, storage: storage, options: options)

        // When 3 apply calls are issued with different tokens
        await applier.apply(flagName: "flag1", resolveToken: "token1")
        await applier.apply(flagName: "flag1", resolveToken: "token2")
        await applier.apply(flagName: "flag1", resolveToken: "token3")

        // Then http client sends 3 post requests
        XCTAssertEqual(httpClient.postCallCounter, 3)
    }

    func testApply_duplicateEventsAreNotSent() async {
        // Given flag applier
        let applier = FlagApplierWithRetries(httpClient: httpClient, storage: storage, options: options)

        // When 3 identical apply calls are issued
        await applier.apply(flagName: "flag1", resolveToken: "token1")
        await applier.apply(flagName: "flag1", resolveToken: "token1")
        await applier.apply(flagName: "flag1", resolveToken: "token1")

        // Then http client sends only 1 post requests
        XCTAssertEqual(httpClient.postCallCounter, 1)
    }

    func testApply_differentFlags() async {
        // Given flag applier
        let applier = FlagApplierWithRetries(httpClient: httpClient, storage: storage, options: options)

        // When 3 apply calls are issued with different flag names
        await applier.apply(flagName: "flag1", resolveToken: "token1")
        await applier.apply(flagName: "flag2", resolveToken: "token1")
        await applier.apply(flagName: "flag3", resolveToken: "token1")

        // Then http client sends only 3 post requests
        XCTAssertEqual(httpClient.postCallCounter, 3)
    }

    func testApply_doesNotstoreOnDisk() async throws {
        // Given flag applier
        let applier = FlagApplierWithRetries(httpClient: httpClient, storage: storage, options: options)

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
                options: options
            )
        }
        await task.value

        // Then http client does not send apply flags batch request
        XCTAssertEqual(httpClient.postCallCounter, 0)
    }

    func testApply_previoslyStoredData_batchTriggered() async throws {
        // Given storage that has previosly stored data (100 records, same token)
        let prefilledStorage = StorageMock()
        let prefilledCache = try prefilledCacheData(sameToken: true)
        try prefilledStorage.save(data: prefilledCache)

        // When flag applier is initialised
        let task = Task {
            _ = FlagApplierWithRetries(
                httpClient: httpClient,
                storage: prefilledStorage,
                options: options
            )
        }
        await task.value

        // Then http client sends apply flags batch request, containing 100 records
        let request = try XCTUnwrap(httpClient.data as? ApplyFlagsRequest)
        XCTAssertEqual(httpClient.postCallCounter, 1)
        XCTAssertEqual(request.flags.count, 100)
    }

    func testApply_previoslyStoredData_cleanAfterSending() async throws {
        // Given storage that has previosly stored data (100 records, same token)
        let prefilledStorage = StorageMock()
        let prefilledCache = try prefilledCacheData(sameToken: true)
        try prefilledStorage.save(data: prefilledCache)

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
        let prefilledCache = try prefilledCacheData(sameToken: true)
        try prefilledStorage.save(data: prefilledCache)

        // When flag applier is initialised
        // And apply flags batch request fails with .invalidResponse
        _ = FlagApplierWithRetries(
            httpClient: offlineClient,
            storage: prefilledStorage,
            options: options
        )

        // Then storage has not been cleaned and contains all 100 records
        let storedData = try prefilledStorage.load(defaultValue: CacheData.empty())
        XCTAssertEqual(storedData.resolveEvents.count, 1)
        XCTAssertEqual(storedData.resolveEvents[0].events.count, 100)
    }

    func testApplyOffline_storesOnDisk() async throws {
        // Given offline http client and flag applier
        let offlineClient = HttpClientMock(testMode: .error)
        let applier = FlagApplierWithRetries(httpClient: offlineClient, storage: storage, options: options)

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
        let applier = FlagApplierWithRetries(httpClient: offlineClient, storage: storage, options: options)

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
            options: options
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
        let prefilledCache = try prefilledCacheData()
        try prefilledStorage.save(data: prefilledCache)
        let applier = FlagApplierWithRetries(
            httpClient: offlineClient,
            storage: prefilledStorage,
            options: options
        )

        // When apply call is issued with another token
        // And http client request fails with .invalidResponse
        await applier.apply(flagName: "flag1", resolveToken: "token1")

        // Then 101 resolve event records are stored on disk
        let storedData: CacheData = try XCTUnwrap(prefilledStorage.load(defaultValue: CacheData.empty()))
        XCTAssertEqual(storedData.resolveEvents.count, 101)
    }

    func testApplyOffline_100applyCalls_sameToken() async throws {
        // Given flag applier set up with offline http client
        // And storage that has previously stored 100 records with same token
        let offlineClient = HttpClientMock(testMode: .error)
        let prefilledStorage = StorageMock()
        let prefilledCache = try prefilledCacheData(sameToken: true)
        try prefilledStorage.save(data: prefilledCache)
        let applier = FlagApplierWithRetries(
            httpClient: offlineClient,
            storage: prefilledStorage,
            options: options
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

    // MARK: Helpers

    private func prefilledFlagEventsData() throws -> CacheData {
        var execution = 1, total = 100
        var flagEvents: [FlagApply] = []
        while execution <= total {
            let uuid = UUID()
            let date = Date(timeIntervalSince1970: Double(execution * 1000))
            let event = FlagApply(name: uuid.uuidString, applyTime: date)
            flagEvents.append(event)

            execution += 1
        }

        let cacheData = CacheData(resolveToken: "token0", events: flagEvents)
        return cacheData
    }

    private func prefilledCacheData(sameToken: Bool = false) throws -> CacheData {
        var cacheData = CacheData.empty()
        for execution in 0..<100 {
            let uuid = UUID()
            let date = Date(timeIntervalSince1970: Double(execution * 1000))
            let token = sameToken ? "token" : uuid.uuidString
            cacheData.add(resolveToken: token, flagName: uuid.uuidString, applyTime: date)
        }

        return cacheData
    }

    private func hundredApplyCalls(applier: FlagApplier, sameToken: Bool = false) async {
        for _ in 0..<100 {
            let uuid = UUID()
            let token = sameToken ? "token" : uuid.uuidString
            await applier.apply(flagName: uuid.uuidString, resolveToken: token)
        }
    }
}
