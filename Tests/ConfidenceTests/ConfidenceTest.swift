// swiftlint:disable type_body_length
// swiftlint:disable file_length
import Foundation
import Combine
import XCTest

@testable import Confidence

extension Date {
    var ISO8601String: String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: self)
    }
}

extension DateComponents {
    var ISO8601String: String {
        if let date = Calendar.current.date(from: self) {
            let formatter = ISO8601DateFormatter()
            formatter.timeZone = TimeZone.current
            formatter.formatOptions = [.withFullDate]
            return formatter.string(from: date)
        }
        return ""
    }
}

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

    func testResolveObjectFlagWithUnderlyingStruct() async throws {
        class FakeClient: ConfidenceResolveClient {
            var resolveStats: Int = 0
            var resolvedValues: [ResolvedValue] = []
            func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
                self.resolveStats += 1
                return .init(resolvedValues: resolvedValues, resolveToken: "token")
            }
        }

        // swiftlint:disable:next line_length
        let expected: ConfidenceValue = .init(structure: ["blob": .init(structure: ["size": .init(integer: 3), "name": .init(string: "testInner")]), "string": .init(string: "test")])
        let client = FakeClient()
        client.resolvedValues = [
            ResolvedValue(
                variant: "control",
                value: expected,
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

        // if the expected output is a struct, it's important the the defaultValue is ConfidenceStruct.
        let defaultValue = ConfidenceStruct(uniqueKeysWithValues: [])
        let evaluation = confidence.getValue(
            key: "flag",
            defaultValue: defaultValue)

        XCTAssertEqual(evaluation, expected.asStructure())
    }


    func testResolveCodable() async throws {
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
                // swiftlint:disable:next line_length
                value: .init(structure: ["blob": .init(structure: ["size": .init(integer: 3), "name": .init(string: "testInner")]), "string": .init(string: "test")]),
                flag: "flag",
                resolveReason: .match,
                shouldApply: false)
        ]

        struct Blob: Codable {
            let size: Int
            let name: String
        }

        struct Flag: Codable {
            let string: String
            let blob: Blob
        }

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()
        let defaultValue = Flag(string: "", blob: Blob(size: 0, name: ""))
        let evaluation = confidence.getValue(
            key: "flag",
            defaultValue: defaultValue)

        let expected = Flag(string: "test", blob: Blob(size: 3, name: "testInner"))
        XCTAssertEqual(evaluation.string, expected.string)
        XCTAssertEqual(evaluation.blob.size, expected.blob.size)
        XCTAssertEqual(evaluation.blob.name, expected.blob.name)
    }

    func testResolveCodableMissingFieldsInResolvedValue() async throws {
        class FakeClient: ConfidenceResolveClient {
            var resolveStats: Int = 0
            var resolvedValues: [ResolvedValue] = []
            func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
                self.resolveStats += 1
                return .init(resolvedValues: resolvedValues, resolveToken: "token")
            }
        }

        let client = FakeClient()
        // Resolved value missing the "blob" field
        client.resolvedValues = [
            ResolvedValue(
                variant: "control",
                value: .init(structure: ["string": .init(string: "test")]),
                flag: "flag",
                resolveReason: .match,
                shouldApply: false)
        ]

        struct Blob: Codable {
            let size: Int
            let name: String
        }

        struct Flag: Codable {
            let string: String
            let blob: Blob
        }

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()
        let defaultValue = Flag(string: "", blob: Blob(size: 0, name: ""))
        let evaluation = confidence.getValue(
            key: "flag",
            defaultValue: defaultValue)

        // Should fall back to default value when fields are missing
        XCTAssertEqual(evaluation.string, "")
        XCTAssertEqual(evaluation.blob.size, 0) // Default value
        XCTAssertEqual(evaluation.blob.name, "") // Default value
    }

    func testResolveCodableExtraFieldsInResolvedValue() async throws {
        class FakeClient: ConfidenceResolveClient {
            var resolveStats: Int = 0
            var resolvedValues: [ResolvedValue] = []
            func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
                self.resolveStats += 1
                return .init(resolvedValues: resolvedValues, resolveToken: "token")
            }
        }

        let client = FakeClient()
        // Resolved value has extra fields not in the struct
        client.resolvedValues = [
            ResolvedValue(
                variant: "control",
                value: .init(structure: [
                    "string": .init(string: "test"),
                    "blob": .init(structure: ["size": .init(integer: 3), "name": .init(string: "testInner")]),
                    "extraField": .init(string: "extra"),
                    "anotherExtra": .init(integer: 42)
                ]),
                flag: "flag",
                resolveReason: .match,
                shouldApply: false)
        ]

        struct Blob: Codable {
            let size: Int
            let name: String
        }

        struct Flag: Codable {
            let string: String
            let blob: Blob
        }

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()
        let defaultValue = Flag(string: "", blob: Blob(size: 0, name: ""))
        let evaluation = confidence.getValue(
            key: "flag",
            defaultValue: defaultValue)

        // Should ignore extra fields and use only the matching ones
        XCTAssertEqual(evaluation.string, "test")
        XCTAssertEqual(evaluation.blob.size, 3)
        XCTAssertEqual(evaluation.blob.name, "testInner")
    }

    func testResolveCodableNestedMissingFields() async throws {
        class FakeClient: ConfidenceResolveClient {
            var resolveStats: Int = 0
            var resolvedValues: [ResolvedValue] = []
            func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
                self.resolveStats += 1
                return .init(resolvedValues: resolvedValues, resolveToken: "token")
            }
        }

        let client = FakeClient()
        // Nested blob missing the "name" field
        client.resolvedValues = [
            ResolvedValue(
                variant: "control",
                value: .init(structure: [
                    "string": .init(string: "test"),
                    "blob": .init(structure: ["size": .init(integer: 3)])
                ]),
                flag: "flag",
                resolveReason: .match,
                shouldApply: false)
        ]

        struct Blob: Codable {
            let size: Int
            let name: String
        }

        struct Flag: Codable {
            let string: String
            let blob: Blob
        }

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()
        let defaultValue = Flag(string: "", blob: Blob(size: 0, name: ""))
        let evaluation = confidence.getValue(
            key: "flag",
            defaultValue: defaultValue)

        // Should use default value due to missing name
        XCTAssertEqual(evaluation.string, "")
        XCTAssertEqual(evaluation.blob.size, 0)
        XCTAssertEqual(evaluation.blob.name, "")
    }

    func testResolveCodableNestedMissingFieldsDefaultValue() async throws {
        class FakeClient: ConfidenceResolveClient {
            var resolveStats: Int = 0
            var resolvedValues: [ResolvedValue] = []
            func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
                self.resolveStats += 1
                return .init(resolvedValues: resolvedValues, resolveToken: "token")
            }
        }

        let client = FakeClient()
        // Nested blob missing the "name" field
        client.resolvedValues = [
            ResolvedValue(
                variant: "control",
                value: .init(structure: [
                    "string": .init(string: "test"),
                    "blob": .init(structure: ["size": .init(integer: 3), "name": .init(string: "Bob")])
                ]),
                flag: "flag",
                resolveReason: .match,
                shouldApply: false)
        ]

        struct Blob: Codable {
            let size: Int
        }

        struct Flag: Codable {
            let string: String
            let blob: Blob
        }

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()
        let defaultValue = Flag(string: "", blob: Blob(size: 0))
        let evaluation = confidence.getValue(
            key: "flag",
            defaultValue: defaultValue)

        // Should use default value due to missing name
        XCTAssertEqual(evaluation.string, "test")
        XCTAssertEqual(evaluation.blob.size, 3)
    }

    func testResolveCodableTypeMismatch() async throws {
        class FakeClient: ConfidenceResolveClient {
            var resolveStats: Int = 0
            var resolvedValues: [ResolvedValue] = []
            func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
                self.resolveStats += 1
                return .init(resolvedValues: resolvedValues, resolveToken: "token")
            }
        }

        let client = FakeClient()
        // Type mismatch: size is string instead of integer
        client.resolvedValues = [
            ResolvedValue(
                variant: "control",
                value: .init(structure: [
                    "string": .init(string: "test"),
                    "blob": .init(structure: [
                        "size": .init(string: "not-a-number"),
                        "name": .init(string: "testInner")
                    ])
                ]),
                flag: "flag",
                resolveReason: .match,
                shouldApply: false)
        ]

        struct Blob: Codable {
            let size: Int
            let name: String
        }

        struct Flag: Codable {
            let string: String
            let blob: Blob
        }

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()
        let defaultValue = Flag(string: "", blob: Blob(size: 0, name: ""))
        let evaluation = confidence.getValue(
            key: "flag",
            defaultValue: defaultValue)

        // Should fall back to default value when type conversion fails
        XCTAssertEqual(evaluation.string, "")
        XCTAssertEqual(evaluation.blob.size, 0) // Default value due to type mismatch
        XCTAssertEqual(evaluation.blob.name, "")
    }

    func testResolveCodableNullValues() async throws {
        class FakeClient: ConfidenceResolveClient {
            var resolveStats: Int = 0
            var resolvedValues: [ResolvedValue] = []
            func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
                self.resolveStats += 1
                return .init(resolvedValues: resolvedValues, resolveToken: "token")
            }
        }

        let client = FakeClient()
        // Some fields are null
        client.resolvedValues = [
            ResolvedValue(
                variant: "control",
                value: .init(structure: [
                    "string": .init(null: ()),
                    "blob": .init(structure: ["size": .init(null: ()), "name": .init(string: "foo")])
                ]),
                flag: "flag",
                resolveReason: .match,
                shouldApply: false)
        ]

        struct Blob: Codable {
            let size: Int
            let name: String
        }

        struct Flag: Codable {
            let string: String
            let blob: Blob
        }

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()
        let defaultValue = Flag(string: "default", blob: Blob(size: 2, name: "default"))
        let evaluation = confidence.getValue(
            key: "flag",
            defaultValue: defaultValue)

        // TODO Not the entire resolved value should be default, only the null fields
        XCTAssertEqual(evaluation.string, "default")
        XCTAssertEqual(evaluation.blob.size, 2)
        XCTAssertEqual(evaluation.blob.name, "default")
    }

    func testResolveCodableOptionalFields() async throws {
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
                    "string": .init(string: "test"),
                    "optionalField": .init(string: "optional"),
                    "blob": .init(structure: ["size": .init(integer: 3), "name": .init(string: "testInner")])
                ]),
                flag: "flag",
                resolveReason: .match,
                shouldApply: false)
        ]

        struct Blob: Codable {
            let size: Int
            let name: String
        }

        struct Flag: Codable {
            let string: String
            let optionalField: String?
            let blob: Blob
        }

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()
        let defaultValue = Flag(string: "", optionalField: nil, blob: Blob(size: 0, name: ""))
        let evaluation = confidence.getValue(
            key: "flag",
            defaultValue: defaultValue)

        // Should handle optional fields correctly
        XCTAssertEqual(evaluation.string, "test")
        XCTAssertEqual(evaluation.optionalField, "optional")
        XCTAssertEqual(evaluation.blob.size, 3)
        XCTAssertEqual(evaluation.blob.name, "testInner")
    }

    func testResolveCodableOptionalFieldsMissing() async throws {
        class FakeClient: ConfidenceResolveClient {
            var resolveStats: Int = 0
            var resolvedValues: [ResolvedValue] = []
            func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
                self.resolveStats += 1
                return .init(resolvedValues: resolvedValues, resolveToken: "token")
            }
        }

        let client = FakeClient()
        // Missing optional field
        client.resolvedValues = [
            ResolvedValue(
                variant: "control",
                value: .init(structure: [
                    "string": .init(string: "test"),
                    "blob": .init(structure: ["size": .init(integer: 3), "name": .init(string: "testInner")])
                ]),
                flag: "flag",
                resolveReason: .match,
                shouldApply: false)
        ]

        struct Blob: Codable {
            let size: Int
            let name: String
        }

        struct Flag: Codable {
            let string: String
            let optionalField: String?
            let blob: Blob
        }

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()
        let defaultValue = Flag(string: "", optionalField: "default", blob: Blob(size: 0, name: ""))
        let evaluation = confidence.getValue(
            key: "flag",
            defaultValue: defaultValue)

        // Should use default value for missing optional field
        XCTAssertEqual(evaluation.string, "test")
        XCTAssertNil(evaluation.optionalField, "")
        XCTAssertEqual(evaluation.blob.size, 3)
        XCTAssertEqual(evaluation.blob.name, "testInner")
    }

    func testResolveCodableDeepNestedStructure() async throws {
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
                    "level1": .init(structure: [
                        "level2": .init(structure: [
                            "level3": .init(structure: [
                                "finalValue": .init(string: "deep")
                            ])
                        ])
                    ])
                ]),
                flag: "flag",
                resolveReason: .match,
                shouldApply: false)
        ]

        struct Level3: Codable {
            let finalValue: String
        }

        struct Level2: Codable {
            let level3: Level3
        }

        struct Level1: Codable {
            let level2: Level2
        }

        struct DeepFlag: Codable {
            let level1: Level1
        }

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()
        let defaultValue = DeepFlag(level1: Level1(level2: Level2(level3: Level3(finalValue: "default"))))
        let evaluation = confidence.getValue(
            key: "flag",
            defaultValue: defaultValue)

        // Should handle deep nested structures correctly
        XCTAssertEqual(evaluation.level1.level2.level3.finalValue, "deep")
    }

    func testResolveCodableArrayFields() async throws {
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
                    "items": .init(list: [
                        .init(string: "item1"),
                        .init(string: "item2"),
                        .init(string: "item3")
                    ]),
                    "numbers": .init(list: [
                        .init(integer: 1),
                        .init(integer: 2),
                        .init(integer: 3)
                    ])
                ]),
                flag: "flag",
                resolveReason: .match,
                shouldApply: false)
        ]

        struct ArrayFlag: Codable {
            let items: [String]
            let numbers: [Int]
        }

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()
        let defaultValue = ArrayFlag(items: [], numbers: [])
        let evaluation = confidence.getValue(
            key: "flag",
            defaultValue: defaultValue)

        // Should handle array fields correctly
        XCTAssertEqual(evaluation.items, ["item1", "item2", "item3"])
        XCTAssertEqual(evaluation.numbers, [1, 2, 3])
    }

    func testResolveCodableAllTypes() async throws {
        class FakeClient: ConfidenceResolveClient {
            var resolveStats: Int = 0
            var resolvedValues: [ResolvedValue] = []
            func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
                self.resolveStats += 1
                return .init(resolvedValues: resolvedValues, resolveToken: "token")
            }
        }

        let client = FakeClient()

        // Create a date and date components for testing
        let testDate = Date(timeIntervalSince1970: 1640995200) // 2022-01-01 00:00:00 UTC
        let testDateComponents = DateComponents(year: 2022, month: 1, day: 1)

        client.resolvedValues = [
            ResolvedValue(
                variant: "control",
                value: .init(structure: [
                    // Boolean type
                    "booleanValue": .init(boolean: true),
                    // String type
                    "stringValue": .init(string: "resolved string"),
                    // Integer type
                    "integerValue": .init(integer: 42),
                    // Double type
                    "doubleValue": .init(double: 3.14159),
                    // Date type (timestamp)
                    "dateValue": .init(timestamp: testDate),
                    // DateComponents type
                    "dateComponentsValue": .init(date: testDateComponents),
                    // List types
                    "booleanList": .init(booleanList: [true, false, true]),
                    "stringList": .init(stringList: ["a", "b", "c"]),
                    "integerList": .init(integerList: [1, 2, 3]),
                    "doubleList": .init(doubleList: [1.1, 2.2, 3.3]),
                    "dateList": .init(dateList: [testDateComponents, testDateComponents]),
                    "timestampList": .init(timestampList: [testDate, testDate]),
                    "anotherList": .init(integerList: [2, 4, 6]),
                    // Nested structure
                    "nestedStruct": .init(structure: [
                        "nestedString": .init(string: "nested value"),
                        "nestedInteger": .init(integer: 100)
                    ]),
                    // Null value
                    "nullValue": .init(null: ())
                ]),
                flag: "flag",
                resolveReason: .match,
                shouldApply: false)
        ]

        struct NestedStruct: Codable {
            let nestedString: String
            let nestedInteger: Int
        }

        struct AllTypesFlag: Codable {
            let booleanValue: Bool
            let stringValue: String
            let integerValue: Int
            let doubleValue: Double
            let dateValue: String // Date serialized as ISO8601 string
            let dateComponentsValue: String // DateComponents serialized as ISO8601 string
            let booleanList: [Bool]
            let stringList: [String]
            let integerList: [Int]
            let doubleList: [Double]
            let dateList: [String] // DateComponents list serialized as ISO8601 strings
            let timestampList: [String] // Date list serialized as ISO8601 strings
            let anotherList: [Int]
            let nestedStruct: NestedStruct
            let nullValue: String? // Optional to handle null
        }

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()

        // Create default values with different types
        let defaultDate = Date(timeIntervalSince1970: 0) // 1970-01-01 00:00:00 UTC
        let defaultDateComponents = DateComponents(year: 1970, month: 1, day: 1)
        let defaultValue = AllTypesFlag(
            booleanValue: false,
            stringValue: "default string",
            integerValue: 0,
            doubleValue: 0.0,
            dateValue: defaultDate.ISO8601String,
            dateComponentsValue: defaultDateComponents.ISO8601String,
            booleanList: [],
            stringList: [],
            integerList: [],
            doubleList: [],
            dateList: [],
            timestampList: [],
            anotherList: [],
            nestedStruct: NestedStruct(nestedString: "default nested", nestedInteger: 0),
            nullValue: "default null"
        )

        let evaluation = confidence.getValue(
            key: "flag",
            defaultValue: defaultValue)

        // Verify all types are correctly resolved
        XCTAssertEqual(evaluation.booleanValue, true)
        XCTAssertEqual(evaluation.stringValue, "resolved string")
        XCTAssertEqual(evaluation.integerValue, 42)
        XCTAssertEqual(evaluation.doubleValue, 3.14159, accuracy: 0.00001)
        XCTAssertEqual(evaluation.dateValue, testDate.ISO8601String)
        XCTAssertEqual(evaluation.dateComponentsValue, testDateComponents.ISO8601String)
        XCTAssertEqual(evaluation.booleanList, [true, false, true])
        XCTAssertEqual(evaluation.stringList, ["a", "b", "c"])
        XCTAssertEqual(evaluation.integerList, [1, 2, 3])
        XCTAssertEqual(evaluation.doubleList, [1.1, 2.2, 3.3])
        XCTAssertEqual(evaluation.dateList, [testDateComponents.ISO8601String, testDateComponents.ISO8601String])
        XCTAssertEqual(evaluation.timestampList, [testDate.ISO8601String, testDate.ISO8601String])
        XCTAssertEqual(evaluation.anotherList, [2, 4, 6])
        XCTAssertEqual(evaluation.nestedStruct.nestedString, "nested value")
        XCTAssertEqual(evaluation.nestedStruct.nestedInteger, 100)
        XCTAssertNil(evaluation.nullValue) // Should be nil for null values
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
            resolveReason: .match,
            shouldApply: true
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
            defaultValue: ConfidenceStruct())

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
        XCTAssertEqual(evaluation.errorCode, .typeMismatch)
        XCTAssertNil(evaluation.errorMessage, "")
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
}

final class DispatchQueueFake: DispatchQueueType {
    var count = 0

    func async(execute work: @escaping @convention(block) () -> Void) {
        count += 1
        work()
    }
}
// swiftlint:enable type_body_length
