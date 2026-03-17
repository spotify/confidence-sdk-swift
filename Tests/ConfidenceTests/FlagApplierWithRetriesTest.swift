// swiftlint:disable type_body_length
// swiftlint:disable file_length
import Foundation
import XCTest

@testable import Confidence

@available(macOS 13.0, iOS 16.0, *)
class FlagApplierWithRetriesTest: XCTestCase {
    private let options = ConfidenceClientOptions(
        credentials: .clientSecret(secret: "test"),
        timeoutIntervalForRequest: 10
    )
    private var applyStorage = StorageMock()
    private var telemetryStorage = StorageMock()
    private var httpClient = HttpClientMock()
    private let metadata = ConfidenceMetadata(name: "test-provider-name", version: "0.0.0.")

    override func setUp() {
        applyStorage = StorageMock()
        telemetryStorage = StorageMock()
        httpClient = HttpClientMock()

        super.setUp()
    }

    func testApply_differentTokens() async {
        let applier = FlagApplierWithRetries(
            httpClient: httpClient,
            applyStorage: applyStorage,
            telemetryStorage: telemetryStorage,
            options: options,
            metadata: metadata,
            triggerBatch: false
        )

        await applier.apply(flagName: "flag1", resolveToken: "token1")
        await applier.apply(flagName: "flag1", resolveToken: "token2")
        await applier.apply(flagName: "flag1", resolveToken: "token3")

        XCTAssertEqual(httpClient.postCallCounter, 3)
    }

    func testApply_duplicateEventsAreNotSent() async {
        let applier = FlagApplierWithRetries(
            httpClient: httpClient,
            applyStorage: applyStorage,
            telemetryStorage: telemetryStorage,
            options: options,
            metadata: metadata,
            triggerBatch: false
        )

        await applier.apply(flagName: "flag1", resolveToken: "token1")
        await applier.apply(flagName: "flag1", resolveToken: "token1")
        await applier.apply(flagName: "flag1", resolveToken: "token1")

        XCTAssertEqual(httpClient.postCallCounter, 1)
    }

    func testApply_differentFlags() async {
        let cacheDataInteractor = CacheDataInteractor(cacheData: .empty())
        let applier = FlagApplierWithRetries(
            httpClient: httpClient,
            applyStorage: applyStorage,
            telemetryStorage: telemetryStorage,
            options: options,
            metadata: metadata,
            cacheDataInteractor: cacheDataInteractor,
            triggerBatch: false
        )

        await applier.apply(flagName: "flag1", resolveToken: "token1")
        await applier.apply(flagName: "flag2", resolveToken: "token1")
        await applier.apply(flagName: "flag3", resolveToken: "token1")

        let cacheData = await cacheDataInteractor.cache

        XCTAssertEqual(httpClient.postCallCounter, 3)
        XCTAssertEqual(cacheData.resolveEvents.count, 1)
        XCTAssertEqual(cacheData.resolveEvents[0].events.count, 3)
    }

    func testApply_doesNotStoreOnDisk() async throws {
        let cacheDataInteractor = CacheDataInteractor(cacheData: .empty())
        let applier = FlagApplierWithRetries(
            httpClient: httpClient,
            applyStorage: applyStorage,
            telemetryStorage: telemetryStorage,
            options: options,
            metadata: metadata,
            cacheDataInteractor: cacheDataInteractor,
            triggerBatch: false
        )

        let networkExpectation = self.expectation(description: "Waiting for network call to complete")
        networkExpectation.expectedFulfillmentCount = 3
        httpClient.expectation = networkExpectation

        await applier.apply(flagName: "flag1", resolveToken: "token1")
        await applier.apply(flagName: "flag2", resolveToken: "token1")
        await applier.apply(flagName: "flag3", resolveToken: "token1")

        await fulfillment(of: [networkExpectation], timeout: 1.0)

        let cacheData = await cacheDataInteractor.cache
        XCTAssertEqual(cacheData.resolveEvents.count, 1)
        XCTAssertEqual(cacheData.resolveEvents[0].events.count, 3)
        XCTAssertTrue(cacheData.resolveEvents[0].events.allSatisfy { $0.status == .sent })

        let storedData = try XCTUnwrap(applyStorage.load(defaultValue: CacheData.empty()))
        XCTAssertEqual(storedData.resolveEvents.count, 0)
    }

    func testApply_emptyStorage_doesNotTriggerBatchApply() async throws {
        let task = Task {
            _ = FlagApplierWithRetries(
                httpClient: httpClient,
                applyStorage: applyStorage,
                telemetryStorage: telemetryStorage,
                options: options,
                metadata: metadata,
                triggerBatch: false
            )
        }
        await task.value

        XCTAssertEqual(httpClient.postCallCounter, 0)
    }

    func testApply_previoslyStoredData_batchTriggered() async throws {
        let prefilledStorage = StorageMock()
        let prefilledCache = try CacheDataUtility.prefilledCacheData(applyEventCount: 100)
        try prefilledStorage.save(data: prefilledCache)

        let expectation = self.expectation(description: "Waiting for network call to complete")
        expectation.expectedFulfillmentCount = 5
        httpClient.expectation = expectation

        let storageExpectation = self.expectation(description: "Waiting for storage expectation to be completed")
        storageExpectation.expectedFulfillmentCount = 10
        prefilledStorage.saveExpectation = storageExpectation

        _ = FlagApplierWithRetries(
            httpClient: httpClient,
            applyStorage: prefilledStorage,
            telemetryStorage: telemetryStorage,
            options: options,
            metadata: metadata
        )

        await fulfillment(of: [storageExpectation, expectation], timeout: 5.0)

        let request = try XCTUnwrap(httpClient.data?.first as? WriteFlagLogsRequest)
        XCTAssertEqual(httpClient.postCallCounter, 5)
        XCTAssertEqual(request.flagAssigned?.first?.flags.count, 20)
    }

    func test_previoslyStoredInTransitData_batchTriggered() async throws {
        let prefilledStorage = StorageMock()
        var prefilledCache = try CacheDataUtility.prefilledCacheData(applyEventCount: 100)
        prefilledCache.setEventStatus(resolveToken: "token0", status: .sending)
        try prefilledStorage.save(data: prefilledCache)

        let expectation = self.expectation(description: "Waiting for network call to complete")
        expectation.expectedFulfillmentCount = 5
        httpClient.expectation = expectation

        let storageExpectation = self.expectation(description: "Waiting for storage expectation to be completed")
        storageExpectation.expectedFulfillmentCount = 10
        prefilledStorage.saveExpectation = storageExpectation

        _ = FlagApplierWithRetries(
            httpClient: httpClient,
            applyStorage: prefilledStorage,
            telemetryStorage: telemetryStorage,
            options: options,
            metadata: metadata
        )

        await fulfillment(of: [storageExpectation, expectation], timeout: 5.0)

        let request = try XCTUnwrap(httpClient.data?.first as? WriteFlagLogsRequest)
        XCTAssertEqual(httpClient.postCallCounter, 5)
        XCTAssertEqual(request.flagAssigned?.first?.flags.count, 20)
    }

    func testApply_previoslyStoredData_partialFailure() async throws {
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

        _ = FlagApplierWithRetries(
            httpClient: partiallyFailingHttpClient,
            applyStorage: prefilledStorage,
            telemetryStorage: telemetryStorage,
            options: options,
            metadata: metadata
        )

        await fulfillment(of: [storageExpectation, expectation], timeout: 5.0)

        let request = try XCTUnwrap(partiallyFailingHttpClient.data?.first as? WriteFlagLogsRequest)
        XCTAssertEqual(partiallyFailingHttpClient.postCallCounter, 5)
        XCTAssertEqual(request.flagAssigned?.first?.flags.count, 20)

        let storedData = try prefilledStorage.load(defaultValue: CacheData.empty())
        XCTAssertEqual(storedData.resolveEvents.count, 1)

        let unsent = try XCTUnwrap(storedData.resolveEvents.first?.events.filter { $0.status == .created })
        XCTAssertEqual(unsent.count, 20)
    }

    func testApply_multipleApplyCalls_batchTriggered() async throws {
        let httpClient = HttpClientMock(testMode: .offline)
        let networkExpectation = self.expectation(description: "Waiting for batch trigger")
        networkExpectation.expectedFulfillmentCount = 2
        httpClient.expectation = networkExpectation

        let applier = FlagApplierWithRetries(
            httpClient: httpClient,
            applyStorage: applyStorage,
            telemetryStorage: telemetryStorage,
            options: options,
            metadata: metadata,
            triggerBatch: false
        )

        await applier.apply(flagName: "flag1", resolveToken: "token1")

        httpClient.testMode = .success
        await applier.apply(flagName: "flag2", resolveToken: "token1")

        await fulfillment(of: [networkExpectation], timeout: 1.0)

        XCTAssertEqual(httpClient.postCallCounter, 2)
        XCTAssertEqual(httpClient.data?.count, 2)

        let request1 = try XCTUnwrap(httpClient.data?[0] as? WriteFlagLogsRequest)
        let request2 = try XCTUnwrap(httpClient.data?[1] as? WriteFlagLogsRequest)
        XCTAssertEqual(request1.flagAssigned?.first?.flags.count, 1)
        XCTAssertEqual(request1.flagAssigned?.first?.flags.first?.flag, "flags/flag1")
        XCTAssertEqual(request2.flagAssigned?.first?.flags.count, 2)
        XCTAssertEqual(request2.flagAssigned?.first?.flags.first?.flag, "flags/flag1")
        XCTAssertEqual(request2.flagAssigned?.first?.flags.last?.flag, "flags/flag2")
    }

    func testApply_multipleApplyCalls_sentSet() async throws {
        let cacheDataInteractor = CacheDataInteractor(cacheData: .empty())
        let offlineClient = HttpClientMock(testMode: .offline)
        let networkExpectation = self.expectation(description: "Waiting for network call to complete")
        networkExpectation.expectedFulfillmentCount = 2
        offlineClient.expectation = networkExpectation

        let storageExpectation = self.expectation(description: "Waiting for storage expectation to be completed")
        storageExpectation.expectedFulfillmentCount = 6
        applyStorage.saveExpectation = storageExpectation

        let applier = FlagApplierWithRetries(
            httpClient: offlineClient,
            applyStorage: applyStorage,
            telemetryStorage: telemetryStorage,
            options: options,
            metadata: metadata,
            cacheDataInteractor: cacheDataInteractor,
            triggerBatch: false
        )

        await applier.apply(flagName: "flag1", resolveToken: "token1")

        offlineClient.testMode = .success
        await applier.apply(flagName: "flag2", resolveToken: "token1")
        await fulfillment(of: [networkExpectation, storageExpectation], timeout: 1.0)

        let cacheData = await cacheDataInteractor.cache
        let flagEvent1 = cacheData.flagEvent(resolveToken: "token1", name: "flag1")
        let flagEvent2 = cacheData.flagEvent(resolveToken: "token1", name: "flag2")

        XCTAssertEqual(flagEvent1?.status, .sent)
        XCTAssertEqual(flagEvent2?.status, .sent)
    }

    func testApply_previoslyStoredData_cleanAfterSending() async throws {
        let prefilledStorage = StorageMock()
        let prefilledCache = try CacheDataUtility.prefilledCacheData(applyEventCount: 100)
        try prefilledStorage.save(data: prefilledCache)

        let storageExpectation = self.expectation(description: "Waiting for storage expectation to be completed")
        storageExpectation.expectedFulfillmentCount = 10
        prefilledStorage.saveExpectation = storageExpectation

        let networkExpectation = self.expectation(description: "Waiting for networkRequest to be completed")
        networkExpectation.expectedFulfillmentCount = 5
        httpClient.expectation = networkExpectation

        _ = FlagApplierWithRetries(
            httpClient: httpClient,
            applyStorage: prefilledStorage,
            telemetryStorage: telemetryStorage,
            options: options,
            metadata: metadata
        )

        await fulfillment(of: [storageExpectation, networkExpectation], timeout: 5.0)

        let storedData = try prefilledStorage.load(defaultValue: CacheData.empty())
        XCTAssertEqual(httpClient.postCallCounter, 5)
        XCTAssertEqual(storedData.resolveEvents.count, 0)
    }

    func testApply_100applyCalls_sameToken() async throws {
        let networkExpectation = self.expectation(description: "Waiting for networkRequest to be completed")
        networkExpectation.expectedFulfillmentCount = 105
        httpClient.expectation = networkExpectation

        let prefilledStorage = StorageMock()
        let prefilledCache = try CacheDataUtility.prefilledCacheData(applyEventCount: 100)
        try prefilledStorage.save(data: prefilledCache)
        let applier = FlagApplierWithRetries(
            httpClient: httpClient,
            applyStorage: prefilledStorage,
            telemetryStorage: telemetryStorage,
            options: options,
            metadata: metadata,
            triggerBatch: false
        )

        await hundredApplyCalls(applier: applier, sameToken: true)
        await fulfillment(of: [networkExpectation], timeout: 1.0)

        let storedData: CacheData = try XCTUnwrap(prefilledStorage.load(defaultValue: CacheData.empty()))
        XCTAssertEqual(storedData.resolveEvents.count, 0)
    }

    func testApply_previoslyStoredData_doesNotCleanAfterSendingFailure() throws {
        let offlineClient = HttpClientMock(testMode: .offline)
        let prefilledStorage = StorageMock()
        let prefilledCache = try CacheDataUtility.prefilledCacheData(applyEventCount: 100)
        try prefilledStorage.save(data: prefilledCache)

        _ = FlagApplierWithRetries(
            httpClient: offlineClient,
            applyStorage: prefilledStorage,
            telemetryStorage: telemetryStorage,
            options: options,
            metadata: metadata,
            triggerBatch: false
        )

        let storedData = try prefilledStorage.load(defaultValue: CacheData.empty())
        XCTAssertEqual(storedData.resolveEvents.count, 1)
        XCTAssertEqual(storedData.resolveEvents[0].events.count, 100)
    }

    func testApplyOffline_storesOnDisk() async throws {
        let offlineClient = HttpClientMock(testMode: .offline)
        let applier = FlagApplierWithRetries(
            httpClient: offlineClient,
            applyStorage: applyStorage,
            telemetryStorage: telemetryStorage,
            options: options,
            metadata: metadata,
            triggerBatch: false
        )

        await applier.apply(flagName: "flag1", resolveToken: "token1")
        await applier.apply(flagName: "flag2", resolveToken: "token1")
        await applier.apply(flagName: "flag3", resolveToken: "token1")

        let storedData = try XCTUnwrap(applyStorage.load(defaultValue: CacheData.empty()))
        let data = try XCTUnwrap(storedData.resolveEvents.first { $0.resolveToken == "token1" })
        XCTAssertEqual(storedData.resolveEvents.count, 1)

        XCTAssertEqual(data.events.count, 3)
        let flag1 = data.events.first { $0.name == "flag1" }
        let flag2 = data.events.first { $0.name == "flag2" }
        let flag3 = data.events.first { $0.name == "flag3" }

        XCTAssertNotNil(flag1)
        XCTAssertNotNil(flag2)
        XCTAssertNotNil(flag3)
    }

    func testApplyOffline_storesOnDisk_multipleTokens() async throws {
        let offlineClient = HttpClientMock(testMode: .offline)
        let applier = FlagApplierWithRetries(
            httpClient: offlineClient,
            applyStorage: applyStorage,
            telemetryStorage: telemetryStorage,
            options: options,
            metadata: metadata,
            triggerBatch: false
        )

        await applier.apply(flagName: "flag1", resolveToken: "token1")
        await applier.apply(flagName: "flag2", resolveToken: "token2")
        await applier.apply(flagName: "flag3", resolveToken: "token3")

        let storedData = try XCTUnwrap(applyStorage.load(defaultValue: CacheData.empty()))
        XCTAssertEqual(storedData.resolveEvents.count, 3)

        let token1 = storedData.resolveEvents.first { $0.resolveToken == "token1" }
        let token2 = storedData.resolveEvents.first { $0.resolveToken == "token2" }
        let token3 = storedData.resolveEvents.first { $0.resolveToken == "token3" }

        XCTAssertEqual(token1?.events.count, 1)
        XCTAssertEqual(token2?.events.count, 1)
        XCTAssertEqual(token3?.events.count, 1)
    }

    func testApplyOffline_previoslyStoredData_storesOnDisk() async throws {
        let offlineClient = HttpClientMock(testMode: .offline)
        let data = CacheData(resolveToken: "token0", flagName: "flag1", applyTime: Date(timeIntervalSince1970: 1000))
        let prefilledStorage = try StorageMock(data: data)

        let networkExpectation = self.expectation(description: "Waiting for networkRequest to be completed")
        networkExpectation.expectedFulfillmentCount = 2
        offlineClient.expectation = networkExpectation

        let applier = FlagApplierWithRetries(
            httpClient: offlineClient,
            applyStorage: prefilledStorage,
            telemetryStorage: telemetryStorage,
            options: options,
            metadata: metadata,
            triggerBatch: false
        )

        await applier.apply(flagName: "flag1", resolveToken: "token1")

        await fulfillment(of: [networkExpectation], timeout: 1.0)

        let storedData: CacheData = try XCTUnwrap(prefilledStorage.load(defaultValue: CacheData.empty()))
        XCTAssertEqual(storedData.resolveEvents.count, 2)

        let newResolveEvent = try XCTUnwrap(storedData.resolveEvents.first { $0.resolveToken == "token0" })
        XCTAssertEqual(newResolveEvent.events.count, 1)
        XCTAssertEqual(newResolveEvent.events[0].name, "flag1")
        XCTAssertEqual(newResolveEvent.events[0].applyTime, Date(timeIntervalSince1970: 1000))
        XCTAssertEqual(newResolveEvent.events[0].status, .created)
    }

    func testApplyOffline_previoslyStoredData_100records() async throws {
        let offlineClient = HttpClientMock(testMode: .offline)
        let prefilledStorage = StorageMock()
        let prefilledCache = try CacheDataUtility.prefilledCacheData(resolveEventCount: 100)
        try prefilledStorage.save(data: prefilledCache)
        let applier = FlagApplierWithRetries(
            httpClient: offlineClient,
            applyStorage: prefilledStorage,
            telemetryStorage: telemetryStorage,
            options: options,
            metadata: metadata,
            triggerBatch: false
        )

        await applier.apply(flagName: "flag1", resolveToken: "token1")

        let storedData: CacheData = try XCTUnwrap(prefilledStorage.load(defaultValue: CacheData.empty()))
        XCTAssertEqual(storedData.resolveEvents.count, 100)
    }

    func testApplyOffline_100applyCalls_sameToken() async throws {
        let offlineClient = HttpClientMock(testMode: .offline)
        let networkExpectation = self.expectation(description: "Waiting for networkRequest to be completed")
        networkExpectation.expectedFulfillmentCount = 800
        offlineClient.expectation = networkExpectation

        let prefilledStorage = StorageMock()
        let prefilledCache = try CacheDataUtility.prefilledCacheData(applyEventCount: 100)
        try prefilledStorage.save(data: prefilledCache)
        let applier = FlagApplierWithRetries(
            httpClient: offlineClient,
            applyStorage: prefilledStorage,
            telemetryStorage: telemetryStorage,
            options: options,
            metadata: metadata,
            triggerBatch: false
        )

        await hundredApplyCalls(applier: applier, sameToken: true)
        await fulfillment(of: [networkExpectation], timeout: 1.0)

        let storedData: CacheData = try XCTUnwrap(prefilledStorage.load(defaultValue: CacheData.empty()))
        XCTAssertEqual(storedData.resolveEvents.count, 1)
        XCTAssertEqual(storedData.resolveEvents[0].events.count, 200)
    }

    // MARK: WriteFlagLogsRequest wire format

    func testApply_sendsWriteFlagLogsRequest() async throws {
        let applier = FlagApplierWithRetries(
            httpClient: httpClient,
            applyStorage: applyStorage,
            telemetryStorage: telemetryStorage,
            options: options,
            metadata: metadata,
            triggerBatch: false
        )

        await applier.apply(flagName: "my-flag", resolveToken: "my-token")

        let request = try XCTUnwrap(httpClient.data?.first as? WriteFlagLogsRequest)
        let flagAssigned = try XCTUnwrap(request.flagAssigned?.first)
        XCTAssertEqual(flagAssigned.resolveId, "my-token")
        XCTAssertEqual(flagAssigned.clientInfo.sdk.id, metadata.name)
        XCTAssertEqual(flagAssigned.clientInfo.sdk.version, metadata.version)
        XCTAssertEqual(flagAssigned.flags.count, 1)
        XCTAssertEqual(flagAssigned.flags.first?.flag, "flags/my-flag")

        XCTAssertNotNil(request.telemetryData)
        XCTAssertEqual(request.telemetryData?.sdk?.id, metadata.name)
    }

    // MARK: Telemetry counters

    func testTelemetry_reportIncrementsErrorCounterAndSends() async throws {
        let counters = TelemetryCounterInteractor(state: .empty())
        let applier = FlagApplierWithRetries(
            httpClient: httpClient,
            applyStorage: applyStorage,
            telemetryStorage: telemetryStorage,
            options: options,
            metadata: metadata,
            telemetryCounters: counters,
            triggerBatch: false
        )

        await applier.report(
            flagName: "missing-flag",
            errorCode: .flagNotFound,
            errorMessage: "Flag 'missing-flag' not found"
        )

        XCTAssertGreaterThanOrEqual(httpClient.postCallCounter, 1)

        let request = try XCTUnwrap(httpClient.data?.last as? WriteFlagLogsRequest)
        XCTAssertNil(request.flagAssigned)
        XCTAssertNotNil(request.telemetryData?.clientErrorRate)

        let errorRates = try XCTUnwrap(request.telemetryData?.clientErrorRate)
        XCTAssertEqual(errorRates.count, 1)
        XCTAssertEqual(errorRates.first?.errorCode, "FLAG_NOT_FOUND")
        XCTAssertEqual(errorRates.first?.count, 1)
    }

    func testTelemetry_trackResolveIncrementsCounter() async throws {
        let counters = TelemetryCounterInteractor(state: .empty())
        let applier = FlagApplierWithRetries(
            httpClient: httpClient,
            applyStorage: applyStorage,
            telemetryStorage: telemetryStorage,
            options: options,
            metadata: metadata,
            telemetryCounters: counters,
            triggerBatch: false
        )

        await applier.trackResolve(reason: .match)
        await applier.trackResolve(reason: .match)
        await applier.trackResolve(reason: .noSegmentMatch)

        let state = await counters.currentState
        XCTAssertEqual(state.resolveRates["RESOLVE_REASON_MATCH"], 2)
        XCTAssertEqual(state.resolveRates["RESOLVE_REASON_NO_SEGMENT_MATCH"], 1)

        // trackResolve does not trigger a batch
        XCTAssertEqual(httpClient.postCallCounter, 0)
    }

    func testTelemetry_countersIncludedInTelemetryRequest() async throws {
        let counters = TelemetryCounterInteractor(state: .empty())
        let applier = FlagApplierWithRetries(
            httpClient: httpClient,
            applyStorage: applyStorage,
            telemetryStorage: telemetryStorage,
            options: options,
            metadata: metadata,
            telemetryCounters: counters,
            triggerBatch: false
        )

        await applier.trackResolve(reason: .match)
        await applier.trackResolve(reason: .match)
        await applier.trackResolve(reason: .stale)

        // Trigger a batch via report (which also adds a client error)
        await applier.report(flagName: "test", errorCode: .evaluationError, errorMessage: nil)

        let request = try XCTUnwrap(httpClient.data?.last as? WriteFlagLogsRequest)
        let resolveRates = try XCTUnwrap(request.telemetryData?.resolveRate)
        let errorRates = try XCTUnwrap(request.telemetryData?.clientErrorRate)

        XCTAssertTrue(resolveRates.contains(ResolveRateRecord(count: 2, reason: "RESOLVE_REASON_MATCH")))
        XCTAssertTrue(resolveRates.contains(ResolveRateRecord(count: 1, reason: "RESOLVE_REASON_STALE")))
        XCTAssertTrue(errorRates.contains(ClientErrorRateRecord(count: 1, errorCode: "EVALUATION_ERROR")))

        // After successful send, counters should be drained
        let state = await counters.currentState
        XCTAssertTrue(state.isEmpty)
    }

    func testTelemetry_reportOffline_persistsCounters() async throws {
        let offlineClient = HttpClientMock(testMode: .offline)
        let counters = TelemetryCounterInteractor(state: .empty())
        let applier = FlagApplierWithRetries(
            httpClient: offlineClient,
            applyStorage: applyStorage,
            telemetryStorage: telemetryStorage,
            options: options,
            metadata: metadata,
            telemetryCounters: counters,
            triggerBatch: false
        )

        await applier.report(
            flagName: "my-flag",
            errorCode: .typeMismatch(),
            errorMessage: nil
        )

        // On failure, counters are restored
        let state = await counters.currentState
        XCTAssertEqual(state.clientErrors["TYPE_MISMATCH"], 1)
    }

    func testTelemetry_multipleErrors_aggregated() async throws {
        let counters = TelemetryCounterInteractor(state: .empty())
        let offlineClient = HttpClientMock(testMode: .offline)
        let applier = FlagApplierWithRetries(
            httpClient: offlineClient,
            applyStorage: applyStorage,
            telemetryStorage: telemetryStorage,
            options: options,
            metadata: metadata,
            telemetryCounters: counters,
            triggerBatch: false
        )

        await applier.report(flagName: "flag1", errorCode: .flagNotFound, errorMessage: nil)
        await applier.report(flagName: "flag2", errorCode: .flagNotFound, errorMessage: nil)
        await applier.report(flagName: "flag3", errorCode: .typeMismatch(), errorMessage: nil)

        let state = await counters.currentState
        XCTAssertEqual(state.clientErrors["FLAG_NOT_FOUND"], 2)
        XCTAssertEqual(state.clientErrors["TYPE_MISMATCH"], 1)
    }

    private func hundredApplyCalls(applier: FlagApplier, sameToken: Bool = false) async {
        for _ in 0..<100 {
            let uuid = UUID()
            let token = sameToken ? "token0" : uuid.uuidString
            await applier.apply(flagName: uuid.uuidString, resolveToken: token)
        }
    }
}
// swiftlint:enable type_body_length
