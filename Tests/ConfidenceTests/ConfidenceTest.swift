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
                resolveReason: .match,
                shouldApply: true)
        ]


        await confidence.putContextAndWait(context: ["targeting_key": .init(string: "user2")])
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
                resolveReason: .match,
                shouldApply: true)
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
                resolveReason: .match,
                shouldApply: true)
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
                resolveReason: .noSegmentMatch,
                shouldApply: true)
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
                resolveReason: .match,
                shouldApply: true)
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
                resolveReason: .match,
                shouldApply: true)
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
                    throw ConfidenceError.internalError(message: "test")
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
                resolveReason: .match,
                shouldApply: true)
        ]

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()
        await confidence.putContextAndWait(context: ["hello": .init(string: "world")])
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
                resolveReason: .match,
                shouldApply: true)
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

    func testAwaitReconciliation() async throws {
        class FakeClient: XCTestCase, ConfidenceResolveClient {
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
                resolveReason: .match,
                shouldApply: true)
        ]

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()
        confidence.putContext(context: ["hello": .init(string: "world")])
        await confidence.awaitReconciliation()
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

    func testAwaitReconciliationFailingTask() async throws {
        class FakeClient: XCTestCase, ConfidenceResolveClient {
            var resolveStats: Int = 0
            var resolvedValues: [ResolvedValue] = []

            func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
                self.resolveStats += 1
                if resolveStats == 1 {
                    // Delay to ensure the second putContext cancels this Task
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                    XCTFail("This line shouldn't be reached as task is expected to be cancelled")
                    return .init(resolvedValues: [], resolveToken: "token")
                } else {
                    if ctx["hello"] == .init(string: "world") {
                        return .init(resolvedValues: resolvedValues, resolveToken: "token")
                    } else {
                        return .init(resolvedValues: [], resolveToken: "token")
                    }
                }
            }
        }

        let client = FakeClient()
        client.resolvedValues = [
            ResolvedValue(
                variant: "control",
                value: .init(structure: ["size": .init(integer: 3)]),
                flag: "flag",
                resolveReason: .match,
                shouldApply: true)
        ]

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .withStorage(storage: storage)
            .build()

        confidence.putContext(context: ["hello": .init(string: "not-world")])
        try await Task.sleep(nanoseconds: 100_000_000)
        Task {
            confidence.putContext(context: ["hello": .init(string: "world")])
        }
        try await Task.sleep(nanoseconds: 100_000_000)
        await confidence.awaitReconciliation()
        let evaluation = confidence.getEvaluation(
            key: "flag.size",
            defaultValue: 0
        )

        XCTAssertEqual(client.resolveStats, 2)
        XCTAssertEqual(evaluation.value, 3)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, .match)
        XCTAssertEqual(evaluation.variant, "control")
        await fulfillment(of: [flagApplier.applyExpectation], timeout: 1)
        XCTAssertEqual(flagApplier.applyCallCount, 1)
    }

    func testAwaitReconciliationFailingTaskAwait() async throws {
        class FakeClient: XCTestCase, ConfidenceResolveClient {
            var resolveStats: Int = 0
            var resolvedValues: [ResolvedValue] = []

            func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
                self.resolveStats += 1
                if resolveStats == 1 {
                    // Delay to ensure the second putContext cancels this Task
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                    XCTFail("This line shouldn't be reached as task is expected to be cancelled")
                    return .init(resolvedValues: [], resolveToken: "token")
                } else {
                    if ctx["hello"] == .init(string: "world") {
                        return .init(resolvedValues: resolvedValues, resolveToken: "token")
                    } else {
                        return .init(resolvedValues: [], resolveToken: "token")
                    }
                }
            }
        }

        let client = FakeClient()
        client.resolvedValues = [
            ResolvedValue(
                variant: "control",
                value: .init(structure: ["size": .init(integer: 3)]),
                flag: "flag",
                resolveReason: .match,
                shouldApply: true)
        ]

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .withStorage(storage: storage)
            .build()

        Task {
            await confidence.putContextAndWait(context: ["hello": .init(string: "not-world")])
        }
        try await Task.sleep(nanoseconds: 100_000_000)
        Task {
            await confidence.putContextAndWait(context: ["hello": .init(string: "world")])
        }
        try await Task.sleep(nanoseconds: 100_000_000)
        await confidence.awaitReconciliation()
        let evaluation = confidence.getEvaluation(
            key: "flag.size",
            defaultValue: 0
        )

        XCTAssertEqual(client.resolveStats, 2)
        XCTAssertEqual(evaluation.value, 3)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, .match)
        XCTAssertEqual(evaluation.variant, "control")
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
                resolveReason: .match,
                shouldApply: true)
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

    func testResolveListFlag() async throws {
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
                value: .init(stringList: ["size", "access"]),
                flag: "flag",
                resolveReason: .match,
                shouldApply: true)
        ]

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()
        let evaluation = confidence.getEvaluation(
            key: "flag",
            defaultValue: ["test"])

        XCTAssertEqual(client.resolveStats, 1)
        XCTAssertEqual(evaluation.value, ["size", "access"])
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
                resolveReason: .match,
                shouldApply: true)
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
        [ResolvedValue(flag: "flag", resolveReason: .targetingKeyError, shouldApply: true)]

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
                resolveReason: .match,
                shouldApply: true)
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
        XCTAssertEqual(evaluation.errorCode, .typeMismatch(message: "Value true cannot be cast to Int"))
        XCTAssertEqual(evaluation.errorMessage, "Value true cannot be cast to Int")
        XCTAssertEqual(evaluation.reason, .error)
        XCTAssertEqual(evaluation.variant, nil)
        XCTAssertEqual(flagApplier.applyCallCount, 0)
    }

    func testShouldNotApply() async throws {
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
                resolveReason: .match,
                shouldApply: false)
        ]

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()
        _ = confidence.getEvaluation(
            key: "flag.size",
            defaultValue: false)

        XCTAssertEqual(flagApplier.applyCallCount, 0)
    }

    func concurrentActivate() async {
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

    func testConcurrentPutContextAndWait() async {
        let confidence = Confidence.Builder(clientSecret: "test").build()
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<1000 {
                group.addTask {
                    await confidence.putContextAndWait(key: "key\(i)", value: ConfidenceValue(string: "value\(i)"))
                }
            }
        }
        await confidence.awaitReconciliation()
        // If we reach here without a crash, the test passes
        XCTAssertTrue(true)
    }

    func testListType() async throws {
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
                value: .init(structure: ["list": .init(integerList: [1, 2, 3])]),
                flag: "flag",
                resolveReason: .match,
                shouldApply: true)
        ]

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()
        let evaluation = confidence.getEvaluation(
            key: "flag",
            defaultValue: ["list": [1]])

        XCTAssertEqual(client.resolveStats, 1)
        XCTAssertEqual(evaluation.value["list"], [1, 2, 3])
        XCTAssertEqual(evaluation.reason, .match)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertNil(evaluation.errorCode)
    }

    // swiftlint:disable:next function_body_length
    func testAllListTypes() async throws {
        class FakeClient: ConfidenceResolveClient {
            var resolveStats: Int = 0
            var resolvedValues: [ResolvedValue] = []
            func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
                self.resolveStats += 1
                return .init(resolvedValues: resolvedValues, resolveToken: "token")
            }
        }

        let testDate = Date(timeIntervalSince1970: 1640995200) // 2022-01-01 00:00:00 UTC
        let testDateComponents = DateComponents(year: 2022, month: 1, day: 1)

        let client = FakeClient()
        client.resolvedValues = [
            ResolvedValue(
                variant: "control",
                value: .init(structure: [
                    "booleanList": .init(booleanList: [true, false, true]),
                    "stringList": .init(stringList: ["a", "b", "c"]),
                    "integerList": .init(integerList: [1, 2, 3]),
                    "doubleList": .init(doubleList: [1.1, 2.2, 3.3]),
                    "dateList": .init(dateList: [testDateComponents, testDateComponents]),
                    "timestampList": .init(timestampList: [testDate, testDate]),
                    "nullList": .init(nullList: [(), ()]),
                    "structureList": .init(list: [
                        .init(structure: ["nested": .init(string: "value1")]),
                        .init(structure: ["nested": .init(string: "value2")])
                    ])
                ]),
                flag: "flag",
                resolveReason: .match,
                shouldApply: true)
        ]

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()
        let evaluation = confidence.getEvaluation(
            key: "flag",
            defaultValue: [
                "booleanList": [false],
                "stringList": ["default"],
                "integerList": [0],
                "doubleList": [0.0],
                "dateList": [testDateComponents],
                "timestampList": [testDate],
                "nullList": [NSNull()],
                "structureList": [["nested": "default"] as [String: Any]]
            ])

        XCTAssertEqual(client.resolveStats, 1)

        // Verify all list types are correctly resolved
        XCTAssertEqual(evaluation.value["booleanList"] as? [Bool], [true, false, true])
        XCTAssertEqual(evaluation.value["stringList"] as? [String], ["a", "b", "c"])
        XCTAssertEqual(evaluation.value["integerList"] as? [Int], [1, 2, 3])
        XCTAssertEqual(evaluation.value["doubleList"] as? [Double], [1.1, 2.2, 3.3])
        XCTAssertEqual(evaluation.value["dateList"] as? [DateComponents], [testDateComponents, testDateComponents])
        XCTAssertEqual(evaluation.value["timestampList"] as? [Date], [testDate, testDate])
        XCTAssertEqual(evaluation.value["nullList"] as? [NSNull], [NSNull(), NSNull()])

        // Verify nested structure list
        if let structureList = evaluation.value["structureList"] as? [[String: Any]] {
            XCTAssertEqual(structureList.count, 2)
            XCTAssertEqual(structureList[0]["nested"] as? String, "value1")
            XCTAssertEqual(structureList[1]["nested"] as? String, "value2")
        } else {
            XCTFail("Expected structureList to be an array of dictionaries")
        }

        XCTAssertEqual(evaluation.reason, .match)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertNil(evaluation.errorCode)
    }

    func testListTypeDirect() async throws {
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
                value: .init(structure: ["list": .init(integerList: [1, 2, 3])]),
                flag: "flag",
                resolveReason: .match,
                shouldApply: true)
        ]

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()
        let evaluation = confidence.getEvaluation(
            key: "flag.list",
            defaultValue: [1])

        XCTAssertEqual(client.resolveStats, 1)
        XCTAssertEqual(evaluation.value, [1, 2, 3])
        XCTAssertEqual(evaluation.reason, .match)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertNil(evaluation.errorCode)
    }

    func testListTypeMismatch() async throws {
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
                value: .init(structure: ["list": .init(integerList: [1, 2, 3])]),
                flag: "flag",
                resolveReason: .match,
                shouldApply: true)
        ]

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()
        let evaluation = confidence.getEvaluation(
            key: "flag.list",
            defaultValue: ["a", "b", "c"])

        XCTAssertEqual(client.resolveStats, 1)
        XCTAssertEqual(evaluation.value, ["a", "b", "c"])
        XCTAssertEqual(evaluation.reason, .error)
        if case .typeMismatch = evaluation.errorCode {
            // success
        } else {
            XCTFail("Expected .typeMismatch error code")
        }
        XCTAssertEqual(evaluation.errorMessage, "List has incompatible element type. Expected string, got integer")
        XCTAssertNotNil(evaluation.errorMessage)
        XCTAssertNil(evaluation.variant)
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
