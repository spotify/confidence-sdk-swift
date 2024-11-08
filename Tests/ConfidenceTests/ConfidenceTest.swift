// swiftlint:disable type_body_length
// swiftlint:disable file_length
import Foundation
import Combine
import XCTest

@testable import Confidence

@available(macOS 13.0, iOS 16.0, *)
class ConfidenceTest: XCTestCase {
    private var flagApplier = FlagApplierMock()
    private let storage = StorageMock()
    private var readyExpectation = XCTestExpectation(description: "Ready")
    override func setUp() {
        try? storage.clear()

        MockedResolveClientURLProtocol.reset()
        flagApplier = FlagApplierMock()

        super.setUp()
    }

    // swiftlint:disable function_body_length
    func testSlowFirstResolveWillbeCancelledOnSecondResolve() async throws {
        let resolve1Completed = expectation(description: "First resolve completed")
        let resolve2Started = expectation(description: "Second resolve has started")
        let resolve2Continues = expectation(description: "Unlock second resolve")
        let resolve2Cancelled = expectation(description: "Second resolve cancelled")
        let resolve3Completed = expectation(description: "Third resolve completed")

        class FakeClient: XCTestCase, ConfidenceResolveClient {
            var callCount = 0
            var resolveContexts: [ConfidenceStruct] = []
            let resolve1Completed: XCTestExpectation
            let resolve2Started: XCTestExpectation
            let resolve2Continues: XCTestExpectation
            let resolve2Cancelled: XCTestExpectation
            let resolve3Completed: XCTestExpectation

            init(
                resolve1Completed: XCTestExpectation,
                resolve2Started: XCTestExpectation,
                resolve2Continues: XCTestExpectation,
                resolve2Cancelled: XCTestExpectation,
                resolve3Completed: XCTestExpectation
            ) {
                self.resolve1Completed = resolve1Completed
                self.resolve2Started = resolve2Started
                self.resolve2Continues = resolve2Continues
                self.resolve2Cancelled = resolve2Cancelled
                self.resolve3Completed = resolve3Completed
                super.init(invocation: nil) // Workaround to use expectations in FakeClient
            }

            func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
                callCount += 1
                switch callCount {
                case 1:
                    if Task.isCancelled {
                        XCTFail("Resolve one was cancelled unexpectedly")
                    } else {
                        resolveContexts.append(ctx)
                        resolve1Completed.fulfill()
                    }
                case 2:
                    resolve2Started.fulfill()
                    await fulfillment(of: [resolve2Continues], timeout: 5.0)
                    if Task.isCancelled {
                        resolve2Cancelled.fulfill()
                        return .init(resolvedValues: [], resolveToken: "")
                    }
                    XCTFail("This task should be cancelled and never reach here")
                case 3:
                    if Task.isCancelled {
                        XCTFail("Resolve three was cancelled unexpectedly")
                    } else {
                        resolveContexts.append(ctx)
                        resolve3Completed.fulfill()
                    }
                default: XCTFail("We expect only 3 resolve calls")
                }
                return .init(resolvedValues: [], resolveToken: "")
            }
        }
        let client = FakeClient(
            resolve1Completed: resolve1Completed,
            resolve2Started: resolve2Started,
            resolve2Continues: resolve2Continues,
            resolve2Cancelled: resolve2Cancelled,
            resolve3Completed: resolve3Completed
        )
        let confidence = Confidence.Builder.init(clientSecret: "")
            .withContext(initialContext: ["targeting_key": .init(string: "user1")])
            .withFlagResolverClient(flagResolver: client)
            .build()

        try await confidence.fetchAndActivate()
        // Initialize allows to start listening for context changes in "confidence"
        // Let the internal "resolve" finish
        await fulfillment(of: [resolve1Completed], timeout: 5.0)
        confidence.putContext(key: "new", value: ConfidenceValue(string: "value"))
        await fulfillment(of: [resolve2Started], timeout: 5.0) // Ensure resolve 2 starts before 3
        confidence.putContext(key: "new2", value: ConfidenceValue(string: "value2"))
        await fulfillment(of: [resolve3Completed], timeout: 5.0)
        resolve2Continues.fulfill() // Allow second resolve to continue, regardless if cancelled or not
        await fulfillment(of: [resolve2Cancelled], timeout: 5.0) // Second resolve is cancelled
        XCTAssertEqual(3, client.callCount)
        XCTAssertEqual(2, client.resolveContexts.count)
        XCTAssertEqual(confidence.getContext(), client.resolveContexts[1])
    }
    // swiftlint:enable function_body_length

    func testRefresh() async throws {
        class FakeClient: ConfidenceResolveClient {
            var resolveStats: Int = 0
            var resolvedValues: [ResolvedValue] = []
            func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
                self.resolveStats += 1
                return .init(resolvedValues: resolvedValues, resolveToken: "token")
            }
        }
        let client = FakeClient()
        let confidence = Confidence.Builder(clientSecret: "test")
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()
        let emptyEvaluation = confidence.getEvaluation(
            key: "flag.size",
            defaultValue: "value"
        )

        XCTAssertEqual(emptyEvaluation.value, "value")
        XCTAssertEqual(emptyEvaluation.errorCode, .flagNotFound)

        client.resolvedValues = [
            ResolvedValue(
                variant: "control",
                value: .init(structure: ["size": .init(integer: 3)]),
                flag: "flag",
                resolveReason: .match)
        ]

        let expectation = expectation(description: "context is synced")
        let cancellable = confidence.contextReconciliatedChanges.sink { _ in
            expectation.fulfill()
        }
        confidence.putContext(context: ["targeting_key": .init(string: "user2")])
        await fulfillment(of: [expectation], timeout: 1)
        cancellable.cancel()

        let evaluation = confidence.getEvaluation(
            key: "flag.size",
            defaultValue: 0)

        XCTAssertEqual(client.resolveStats, 2)
        XCTAssertEqual(evaluation.value, 3)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, .match)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(client.resolveStats, 2)
        await fulfillment(of: [flagApplier.applyExpectation], timeout: 1)
        XCTAssertEqual(flagApplier.applyCallCount, 1)
    }

    func testResolveIntegerFlag() async throws {
        class FakeClient: ConfidenceResolveClient {
            var resolveStats: Int = 0
            var resolvedValues: [ResolvedValue] = []
            func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
                self.resolveStats += 1
                return .init(resolvedValues: resolvedValues, resolveToken: "token")
            }
        }

        let client = FakeClient()
        client.resolvedValues = [
            ResolvedValue(
                variant: "control",
                value: .init(structure: ["size": .init(integer: 3)]),
                flag: "flag",
                resolveReason: .match)
        ]

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()
        let evaluation = confidence.getEvaluation(
            key: "flag.size",
            defaultValue: 0)

        XCTAssertEqual(client.resolveStats, 1)
        XCTAssertEqual(evaluation.value, 3)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, .match)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(client.resolveStats, 1)
        await fulfillment(of: [flagApplier.applyExpectation], timeout: 1)
        XCTAssertEqual(flagApplier.applyCallCount, 1)
    }


    func testResolveIntegerFlagWithInt64() async throws {
        class FakeClient: ConfidenceResolveClient {
            var resolveStats: Int = 0
            var resolvedValues: [ResolvedValue] = []
            func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
                self.resolveStats += 1
                return .init(resolvedValues: resolvedValues, resolveToken: "token")
            }
        }

        let client = FakeClient()
        client.resolvedValues = [
            ResolvedValue(
                variant: "control",
                value: .init(structure: ["size": .init(integer: 3)]),
                flag: "flag",
                resolveReason: .match)
        ]

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()
        let value = confidence.getValue(
            key: "flag.size",
            defaultValue: 0 as Int64)

        XCTAssertEqual(client.resolveStats, 1)
        XCTAssertEqual(value, 3)
        XCTAssertEqual(client.resolveStats, 1)
        await fulfillment(of: [flagApplier.applyExpectation], timeout: 1)
        XCTAssertEqual(flagApplier.applyCallCount, 1)
    }


    func testResolveAndApplyIntegerFlagNoSegmentMatch() async throws {
        class FakeClient: ConfidenceResolveClient {
            var resolveStats: Int = 0
            var resolvedValues: [ResolvedValue] = []
            func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
                self.resolveStats += 1
                return .init(resolvedValues: resolvedValues, resolveToken: "token")
            }
        }

        let client = FakeClient()
        client.resolvedValues = [
            ResolvedValue(
                value: .init(structure: ["size": .init(integer: 3)]),
                flag: "flag",
                resolveReason: .noSegmentMatch)
        ]

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user1")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()
        let evaluation = confidence.getEvaluation(
            key: "flag.size",
            defaultValue: 0)

        XCTAssertEqual(client.resolveStats, 1)
        XCTAssertEqual(evaluation.value, 0)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, .noSegmentMatch)
        XCTAssertNil(evaluation.variant)
        XCTAssertEqual(client.resolveStats, 1)
        await fulfillment(of: [flagApplier.applyExpectation], timeout: 1)
        XCTAssertEqual(flagApplier.applyCallCount, 1)
    }

    func testResolveAndApplyIntegerFlagNullValue() async throws {
        class FakeClient: ConfidenceResolveClient {
            var resolveStats: Int = 0
            var resolvedValues: [ResolvedValue] = []
            func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
                self.resolveStats += 1
                return .init(resolvedValues: resolvedValues, resolveToken: "token")
            }
        }

        let client = FakeClient()
        client.resolvedValues = [
            ResolvedValue(
                value: .init(structure: ["size": .init(null: ())]),
                flag: "flag",
                resolveReason: .match)
        ]

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()
        let evaluation = confidence.getEvaluation(
            key: "flag.size",
            defaultValue: 4)

        XCTAssertEqual(client.resolveStats, 1)
        XCTAssertEqual(evaluation.value, 4)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, .match)
        XCTAssertNil(evaluation.variant)
        XCTAssertEqual(client.resolveStats, 1)
        await fulfillment(of: [flagApplier.applyExpectation], timeout: 1)
        XCTAssertEqual(flagApplier.applyCallCount, 1)
    }

    func testResolveAndApplyIntegerFlagTwice() async throws {
        class FakeClient: ConfidenceResolveClient {
            var resolveStats: Int = 0
            var resolvedValues: [ResolvedValue] = []
            func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
                self.resolveStats += 1
                return .init(resolvedValues: resolvedValues, resolveToken: "token")
            }
        }

        let client = FakeClient()
        client.resolvedValues = [
            ResolvedValue(
                variant: "control",
                value: .init(structure: ["size": .init(integer: 3)]),
                flag: "flag",
                resolveReason: .match)
        ]

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()
        let evaluation = confidence.getEvaluation(
            key: "flag.size",
            defaultValue: 0)

        _ = confidence.getEvaluation(
            key: "flag.size",
            defaultValue: 0)

        XCTAssertEqual(client.resolveStats, 1)
        XCTAssertEqual(evaluation.value, 3)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, .match)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(client.resolveStats, 1)
        await fulfillment(of: [flagApplier.applyExpectation], timeout: 1)
        XCTAssertEqual(flagApplier.applyCallCount, 2)
    }

    func testStaleEvaluationContextInCache() async throws {
        class FakeClient: XCTestCase, ConfidenceResolveClient {
            var resolveStats: Int = 0
            var resolvedValues: [ResolvedValue] = []
            func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
                if self.resolveStats == 1 {
                    let expectation = expectation(description: "never fullfil")
                    await fulfillment(of: [expectation])
                }
                self.resolveStats += 1
                return .init(resolvedValues: resolvedValues, resolveToken: "token")
            }
        }

        let client = FakeClient()
        client.resolvedValues = [
            ResolvedValue(
                variant: "control",
                value: .init(structure: ["size": .init(integer: 3)]),
                flag: "flag",
                resolveReason: .match)
        ]

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()
        confidence.putContext(context: ["hello": .init(string: "world")])
        let evaluation = confidence.getEvaluation(
            key: "flag.size",
            defaultValue: 0)

        XCTAssertEqual(client.resolveStats, 1)
        XCTAssertEqual(evaluation.value, 3)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, .stale)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(client.resolveStats, 1)
        await fulfillment(of: [flagApplier.applyExpectation], timeout: 1)
        XCTAssertEqual(flagApplier.applyCallCount, 1)
    }

    func testResolveDoubleFlag() async throws {
        class FakeClient: ConfidenceResolveClient {
            var resolveStats: Int = 0
            var resolvedValues: [ResolvedValue] = []
            func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
                self.resolveStats += 1
                return .init(resolvedValues: resolvedValues, resolveToken: "token")
            }
        }

        let client = FakeClient()
        client.resolvedValues = [
            ResolvedValue(
                variant: "control",
                value: .init(structure: ["size": .init(double: 3.14)]),
                flag: "flag",
                resolveReason: .match)
        ]

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()
        let evaluation = confidence.getEvaluation(
            key: "flag.size",
            defaultValue: 0.0)

        XCTAssertEqual(client.resolveStats, 1)
        XCTAssertEqual(evaluation.value, 3.14)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, .match)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(client.resolveStats, 1)
        await fulfillment(of: [flagApplier.applyExpectation], timeout: 1)
        XCTAssertEqual(flagApplier.applyCallCount, 1)
    }

    func testResolveBooleanFlag() async throws {
        class FakeClient: ConfidenceResolveClient {
            var resolveStats: Int = 0
            var resolvedValues: [ResolvedValue] = []
            func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
                self.resolveStats += 1
                return .init(resolvedValues: resolvedValues, resolveToken: "token")
            }
        }

        let client = FakeClient()
        client.resolvedValues = [
            ResolvedValue(
                variant: "control",
                value: .init(structure: ["size": .init(boolean: true)]),
                flag: "flag",
                resolveReason: .match)
        ]

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()
        let evaluation = confidence.getEvaluation(
            key: "flag.size",
            defaultValue: false)

        XCTAssertEqual(client.resolveStats, 1)
        XCTAssertEqual(evaluation.value, true)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, .match)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(client.resolveStats, 1)
        await fulfillment(of: [flagApplier.applyExpectation], timeout: 1)
        XCTAssertEqual(flagApplier.applyCallCount, 1)
    }

    func testResolveObjectFlag() async throws {
        class FakeClient: ConfidenceResolveClient {
            var resolveStats: Int = 0
            var resolvedValues: [ResolvedValue] = []
            func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
                self.resolveStats += 1
                return .init(resolvedValues: resolvedValues, resolveToken: "token")
            }
        }

        let client = FakeClient()
        let value = ResolvedValue(
            variant: "control",
            value: .init(structure: ["size": .init(structure: ["boolean": .init(boolean: true)])]),
            flag: "flag",
            resolveReason: .match
        )
        client.resolvedValues = [value]

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()
        let evaluation = confidence.getEvaluation(
            key: "flag.size",
            defaultValue: [:])

        XCTAssertEqual(client.resolveStats, 1)
        XCTAssertEqual(evaluation.value as? ConfidenceStruct, ["boolean": .init(boolean: true)])
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, .match)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(client.resolveStats, 1)
        await fulfillment(of: [flagApplier.applyExpectation], timeout: 1)
        XCTAssertEqual(flagApplier.applyCallCount, 1)
    }

    func testResolveNullValues() async throws {
        class FakeClient: ConfidenceResolveClient {
            var resolveStats: Int = 0
            var resolvedValues: [ResolvedValue] = []
            func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
                self.resolveStats += 1
                return .init(resolvedValues: resolvedValues, resolveToken: "token")
            }
        }

        let client = FakeClient()
        client.resolvedValues = [
            ResolvedValue(
                variant: "control",
                value: .init(structure: ["size": .init(null: ())]),
                flag: "flag",
                resolveReason: .match)
        ]

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()
        let evaluation = confidence.getEvaluation(
            key: "flag.size",
            defaultValue: 42)

        XCTAssertEqual(client.resolveStats, 1)
        XCTAssertEqual(evaluation.value, 42)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, .match)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(client.resolveStats, 1)
        await fulfillment(of: [flagApplier.applyExpectation], timeout: 5)
        XCTAssertEqual(flagApplier.applyCallCount, 1)
    }

    func testProviderFlagNotFound() async throws {
        class FakeClient: ConfidenceResolveClient {
            var resolveStats: Int = 0
            var resolvedValues: [ResolvedValue] = []
            func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
                self.resolveStats += 1
                return .init(resolvedValues: resolvedValues, resolveToken: "token")
            }
        }

        let client = FakeClient()

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()
        let evaluation = confidence.getEvaluation(
            key: "flag.size",
            defaultValue: 42
        )

        XCTAssertEqual(evaluation.value, 42)
        XCTAssertNil(evaluation.variant)
        XCTAssertEqual(evaluation.reason, .error)
        XCTAssertEqual(evaluation.errorCode, .flagNotFound)
        XCTAssertEqual(evaluation.errorMessage, "Flag 'flag' not found in local cache")
        XCTAssertEqual(client.resolveStats, 1)
    }

    func testProviderTargetingKeyError() async throws {
        class FakeClient: ConfidenceResolveClient {
            var resolveStats: Int = 0
            var resolvedValues: [ResolvedValue] = []
            func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
                self.resolveStats += 1
                return .init(resolvedValues: resolvedValues, resolveToken: "token")
            }
        }

        let client = FakeClient()
        client.resolvedValues =
        [ResolvedValue(flag: "flag", resolveReason: .targetingKeyError)]

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()
        let evaluation = confidence.getEvaluation(
            key: "flag.size",
            defaultValue: 42)

        XCTAssertEqual(client.resolveStats, 1)
        XCTAssertEqual(evaluation.value, 42)
        XCTAssertEqual(evaluation.errorCode, .invalidContext)
        XCTAssertEqual(evaluation.errorMessage, "Invalid targeting key")
        XCTAssertEqual(evaluation.reason, .targetingKeyError)
        XCTAssertEqual(evaluation.variant, nil)
        XCTAssertEqual(client.resolveStats, 1)
        XCTAssertEqual(flagApplier.applyCallCount, 0)
    }

    func testInvalidContextInMessage() async throws {
        let confidence = Confidence.Builder(clientSecret: "test")
            .build()

        XCTAssertThrowsError(
            try confidence.track(eventName: "test", data: ["context": ConfidenceValue(string: "test")])
        ) { error in
            XCTAssertEqual(error as? ConfidenceError, ConfidenceError.invalidContextInMessage)
        }
    }

    func testTypeMismatch() async throws {
        class FakeClient: ConfidenceResolveClient {
            var resolveStats: Int = 0
            var resolvedValues: [ResolvedValue] = []
            func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
                self.resolveStats += 1
                return .init(resolvedValues: resolvedValues, resolveToken: "token")
            }
        }

        let client = FakeClient()
        client.resolvedValues = [
            ResolvedValue(
                variant: "control",
                value: .init(structure: ["size": .init(boolean: true)]),
                flag: "flag",
                resolveReason: .match)
        ]

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user1")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()
        let evaluation = confidence.getEvaluation(
            key: "flag.size",
            defaultValue: 1)

        XCTAssertEqual(client.resolveStats, 1)
        XCTAssertEqual(evaluation.value, 1)
        XCTAssertEqual(evaluation.errorCode, .typeMismatch)
        XCTAssertNil(evaluation.errorMessage, "")
        XCTAssertEqual(evaluation.reason, .error)
        XCTAssertEqual(evaluation.variant, nil)
        XCTAssertEqual(flagApplier.applyCallCount, 0)
    }

    func testConcurrentActivate() async {
        for _ in 1...100 {
            Task {
                await concurrentActivate()
            }
        }
    }

    private func concurrentActivate() async {
        let confidence = Confidence.Builder(clientSecret: "test")
            .build()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10000 {
                group.addTask {
                    // no need to handle errors
                    // race condition crashes will surface regardless
                    try? confidence.activate()
                }
            }
        }
    }
}

final class DispatchQueueFake: DispatchQueueType {
    var count = 0

    func async(execute work: @escaping @convention(block) () -> Void) {
        count += 1
        work()
    }
}
// swiftlint:enable type_body_length
