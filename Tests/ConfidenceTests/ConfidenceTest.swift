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

    func testResolveStruct() async throws {
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
            key: "flag",
            defaultValue: ["size": 0]
        )

        XCTAssertEqual(client.resolveStats, 1)
        XCTAssertEqual(evaluation.value, ["size": 3])
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, .match)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(client.resolveStats, 1)
        await fulfillment(of: [flagApplier.applyExpectation], timeout: 5)
        XCTAssertEqual(flagApplier.applyCallCount, 1)
    }

    func testResolveInnerStruct() async throws {
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
                value: .init(structure: ["size": .init(structure: ["border": ConfidenceValue.init(integer: 420)])]),
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
            defaultValue: ["size": ["border": 0]]
        )

        XCTAssertEqual(client.resolveStats, 1)
        XCTAssertEqual(evaluation.value, ["size": ["border": 420]])
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, .match)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(client.resolveStats, 1)
        await fulfillment(of: [flagApplier.applyExpectation], timeout: 5)
        XCTAssertEqual(flagApplier.applyCallCount, 1)
    }

    func testResolveStructSchemaMismatch() async throws {
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
                value: .init(structure: ["size": .init(integer: 44)]),
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
            defaultValue: ["test": "wrong_type"]
        )

        XCTAssertEqual(client.resolveStats, 1)
        XCTAssertEqual(evaluation.value, ["test": "wrong_type"])
        XCTAssertEqual(evaluation.errorCode, .typeMismatch(
            message: "Value 44 cannot be cast to Dictionary<String, String>"))
        XCTAssertEqual(evaluation.errorMessage, "Value 44 cannot be cast to Dictionary<String, String>")
        XCTAssertEqual(evaluation.reason, .error)
        XCTAssertNil(evaluation.variant)
        XCTAssertEqual(client.resolveStats, 1)
        XCTAssertEqual(flagApplier.applyCallCount, 0)
    }

    func testResolveStructSchemaExtraValues() async throws {
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
                value: .init(structure: [
                    "width": .init(integer: 200),
                    "height": .init(integer: 400)
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
            defaultValue: ["width": 100]
        )

        XCTAssertEqual(client.resolveStats, 1)
        XCTAssertEqual(evaluation.value, ["width": 200, "height": 400])
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, .match)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(client.resolveStats, 1)
        await fulfillment(of: [flagApplier.applyExpectation], timeout: 5)
        XCTAssertEqual(flagApplier.applyCallCount, 1)
    }

    func testResolveStructHeterogenous() async throws {
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
                value: .init(structure: [
                    "width": .init(integer: 200),
                    "color": .init(string: "yellow")
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
            defaultValue: ["width": 100, "color": "black"]
        )

        XCTAssertEqual(client.resolveStats, 1)
        let expected: [String: AnyHashable] = ["width": 200, "color": "yellow"]
        XCTAssertEqual(evaluation.value as? [String: AnyHashable], expected)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, .match)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(client.resolveStats, 1)
        await fulfillment(of: [flagApplier.applyExpectation], timeout: 5)
        XCTAssertEqual(flagApplier.applyCallCount, 1)
    }

    func testResolveStructHeterogenousExtraValueInFlag() async throws {
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
                value: .init(structure: [
                    "width": .init(integer: 200),
                    "color": .init(string: "yellow"),
                    "error": .init(string: "Unknown")
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
            defaultValue: ["width": 100, "color": "black"]
        )

        XCTAssertEqual(client.resolveStats, 1)
        let expected: [String: AnyHashable] = ["width": 200, "color": "yellow", "error": "Unknown"]
        XCTAssertEqual(evaluation.value as? [String: AnyHashable], expected)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, .match)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(client.resolveStats, 1)
        await fulfillment(of: [flagApplier.applyExpectation], timeout: 5)
        XCTAssertEqual(flagApplier.applyCallCount, 1)
    }

    func testResolveStructHeterogenousExtraValueInDefaultValue() async throws {
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
                value: .init(structure: [
                    "width": .init(integer: 200),
                    "color": .init(string: "yellow")
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
            defaultValue: ["width": 100, "color": "black", "error": "Unknown"]
        )

        XCTAssertEqual(client.resolveStats, 1)
        let expected: [String: AnyHashable] = ["width": 200, "color": "yellow"]
        XCTAssertEqual(evaluation.value as? [String: AnyHashable], expected)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, .match)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(client.resolveStats, 1)
        await fulfillment(of: [flagApplier.applyExpectation], timeout: 5)
        XCTAssertEqual(flagApplier.applyCallCount, 1)
    }

    func testResolveStructHeterogenousMismatch() async throws {
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
                value: .init(structure: [
                    "width": .init(integer: 200),
                    "color": .init(string: "yellow")
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
            defaultValue: ["width": 100]
        )

        XCTAssertEqual(client.resolveStats, 1)
        XCTAssertEqual(evaluation.value, ["width": 100])
        if case let .typeMismatch(message) = evaluation.errorCode {
            XCTAssertTrue(message.hasSuffix("cannot be cast to Dictionary<String, Int>"))
            XCTAssertTrue(message.contains("\"width\": \"200\""))
            XCTAssertTrue(message.contains("\"color\": \"yellow\""))
        } else {
            XCTFail("Expected .typeMismatch but got \(String(describing: evaluation.errorCode))")
        }
        let errorMessage = evaluation.errorMessage ?? ""
        XCTAssertTrue(errorMessage.hasSuffix("cannot be cast to Dictionary<String, Int>"))
        XCTAssertTrue(errorMessage.contains("\"width\": \"200\""))
        XCTAssertTrue(errorMessage.contains("\"color\": \"yellow\""))
        XCTAssertEqual(evaluation.reason, .error)
        XCTAssertNil(evaluation.variant)
        XCTAssertEqual(client.resolveStats, 1)
        XCTAssertEqual(flagApplier.applyCallCount, 0)
    }

    func testResolveStructConfidenceValueDefault() async throws {
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
            key: "flag",
            defaultValue: ConfidenceValue.init(structure: ["size": .init(integer: 4)]))

        XCTAssertEqual(client.resolveStats, 1)
        XCTAssertEqual(evaluation.value, ConfidenceValue.init(structure: ["size": .init(integer: 4)]))
        XCTAssertEqual(evaluation.errorCode, .typeMismatch(
            message: "Value [\"size\": \"3\"] cannot be cast to ConfidenceValue"))
        XCTAssertEqual(evaluation.errorMessage, "Value [\"size\": \"3\"] cannot be cast to ConfidenceValue")
        XCTAssertEqual(evaluation.reason, .error)
        XCTAssertNil(evaluation.variant)
        XCTAssertEqual(client.resolveStats, 1)
        XCTAssertEqual(flagApplier.applyCallCount, 0)
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
}

final class DispatchQueueFake: DispatchQueueType {
    var count = 0

    func async(execute work: @escaping @convention(block) () -> Void) {
        count += 1
        work()
    }
}
// swiftlint:enable type_body_length
