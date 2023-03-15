import Foundation
import OpenFeature
import XCTest

@testable import KonfidensProvider

class KonfidensFeatureProviderTest: XCTestCase {
    private let builder = KonfidensFeatureProvider.Builder(credentials: .clientSecret(secret: "test"))

    override func setUp() {
        try? PersistentBatchProviderCache.fromDefaultStorage().clear()
        MockedKonfidensClientURLProtocol.reset()

        super.setUp()
    }

    func testResolveIntegerFlag() throws {
        let resolve: [String: MockedKonfidensClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .integer(3)]))
        ]

        let flags: [String: MockedKonfidensClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let session = MockedKonfidensClientURLProtocol.mockedSession(flags: flags)
        let provider = builder.with(session: session).build()

        let evaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 0,
            ctx: MutableContext(targetingKey: "user1"))

        XCTAssertEqual(evaluation.value, 3)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, Reason.targetingMatch.rawValue)
        XCTAssertEqual(evaluation.variant, "control")
    }

    func testResolveObjectFlag() throws {
        let resolve: [String: MockedKonfidensClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .integer(3)]))
        ]

        let flags: [String: MockedKonfidensClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let session = MockedKonfidensClientURLProtocol.mockedSession(flags: flags)
        let provider = builder.with(session: session).build()

        let evaluation = try provider.getObjectEvaluation(
            key: "flag",
            defaultValue: .structure(["size": .integer(0)]),
            ctx: MutableContext(targetingKey: "user1"))

        XCTAssertEqual(evaluation.value, .structure(["size": .integer(3)]))
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, Reason.targetingMatch.rawValue)
        XCTAssertEqual(evaluation.variant, "control")
    }

    func testResolveNullValues() throws {
        let resolve: [String: MockedKonfidensClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .null]))
        ]

        let schemas: [String: StructFlagSchema] = [
            "user1": .init(schema: ["size": .intSchema])
        ]

        let flags: [String: MockedKonfidensClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve, schemas: schemas)
        ]

        let session = MockedKonfidensClientURLProtocol.mockedSession(flags: flags)
        let provider = builder.with(session: session).build()

        let evaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 42,
            ctx: MutableContext(targetingKey: "user1"))

        XCTAssertEqual(evaluation.value, 42)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, Reason.targetingMatch.rawValue)
        XCTAssertEqual(evaluation.variant, "control")
    }

    func testProviderThrowsFlagNotFound() throws {
        let session = MockedKonfidensClientURLProtocol.mockedSession(flags: [:])
        let provider = builder.with(session: session).build()

        XCTAssertThrowsError(
            try provider.getObjectEvaluation(
                key: "flag",
                defaultValue: .structure(["size": .integer(0)]),
                ctx: MutableContext(targetingKey: "user1"))
        ) { error in
            XCTAssertEqual(error as? OpenFeatureError, OpenFeatureError.flagNotFoundError(key: "flag"))
        }
    }

    func testProviderThrowsMissingTargetingKey() throws {
        let session = MockedKonfidensClientURLProtocol.mockedSession(flags: [:])
        let provider = builder.with(session: session).build()

        XCTAssertThrowsError(
            try provider.getIntegerEvaluation(
                key: "flag.size",
                defaultValue: 3,
                ctx: MutableContext(attributes: [:]))
        ) { error in
            XCTAssertEqual(error as? OpenFeatureError, OpenFeatureError.targetingKeyMissingError)
        }
    }

    func testProviderCannotParse() throws {
        let resolve: [String: MockedKonfidensClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .integer(3)]))
        ]

        let flags: [String: MockedKonfidensClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let session = MockedKonfidensClientURLProtocol.mockedSession(flags: flags)
        let provider = builder.with(session: session).build()

        XCTAssertThrowsError(
            try provider.getStringEvaluation(
                key: "flag.size",
                defaultValue: "value",
                ctx: MutableContext(targetingKey: "user1"))
        ) { error in
            XCTAssertEqual(
                error as? OpenFeatureError, OpenFeatureError.parseError(message: "Unable to parse flag value: 3"))
        }
    }

    func testLocalOverrideReplacesFlag() throws {
        let resolve: [String: MockedKonfidensClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .integer(3)]))
        ]

        let flags: [String: MockedKonfidensClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let session = MockedKonfidensClientURLProtocol.mockedSession(flags: flags)
        let provider = builder.with(session: session)
            .overrides(.flag(name: "flag", variant: "control", value: ["size": .integer(4)]))
            .build()

        let evaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 0,
            ctx: MutableContext(targetingKey: "user1"))

        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(evaluation.reason, Reason.defaultReason.rawValue)
        XCTAssertEqual(evaluation.value, 4)
    }

    func testLocalOverridePartiallyReplacesFlag() throws {
        let resolve: [String: MockedKonfidensClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .integer(3), "color": .string("green")]))
        ]

        let flags: [String: MockedKonfidensClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let session = MockedKonfidensClientURLProtocol.mockedSession(flags: flags)
        let provider = builder.with(session: session)
            .overrides(.field(path: "flag.size", variant: "treatment", value: .integer(4)))
            .build()

        let sizeEvaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 0,
            ctx: MutableContext(targetingKey: "user1"))

        XCTAssertEqual(sizeEvaluation.variant, "treatment")
        XCTAssertEqual(sizeEvaluation.reason, Reason.defaultReason.rawValue)
        XCTAssertEqual(sizeEvaluation.value, 4)

        let colorEvaluation = try provider.getStringEvaluation(
            key: "flag.color",
            defaultValue: "blue",
            ctx: MutableContext(targetingKey: "user1"))

        XCTAssertEqual(colorEvaluation.variant, "control")
        XCTAssertEqual(colorEvaluation.reason, Reason.targetingMatch.rawValue)
        XCTAssertEqual(colorEvaluation.value, "green")
    }

    func testLocalOverrideTwiceTakesSecondOverride() throws {
        let resolve: [String: MockedKonfidensClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .integer(3)]))
        ]

        let flags: [String: MockedKonfidensClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let session = MockedKonfidensClientURLProtocol.mockedSession(flags: flags)
        let provider = builder.with(session: session)
            .overrides(.field(path: "flag.size", variant: "control", value: .integer(4)))
            .overrides(.field(path: "flag.size", variant: "treatment", value: .integer(5)))
            .build()

        let evaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 0,
            ctx: MutableContext(targetingKey: "user1"))

        XCTAssertEqual(evaluation.variant, "treatment")
        XCTAssertEqual(evaluation.reason, Reason.defaultReason.rawValue)
        XCTAssertEqual(evaluation.value, 5)
    }

    func testOverridingInProvider() throws {
        let resolve: [String: MockedKonfidensClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .integer(3)]))
        ]

        let flags: [String: MockedKonfidensClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let session = MockedKonfidensClientURLProtocol.mockedSession(flags: flags)
        let provider = builder.with(session: session)
            .build()

        provider.overrides(.field(path: "flag.size", variant: "treatment", value: .integer(5)))

        let evaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 0,
            ctx: MutableContext(targetingKey: "user1"))

        XCTAssertEqual(evaluation.variant, "treatment")
        XCTAssertEqual(evaluation.reason, Reason.defaultReason.rawValue)
        XCTAssertEqual(evaluation.value, 5)
    }

    func testResolvingArchivedFlag() throws {
        let session = MockedKonfidensClientURLProtocol.mockedSession(flags: [
            "flags/archived": .init(resolve: [:], isArchived: true)
        ])
        let provider = builder.with(session: session).build()

        XCTAssertThrowsError(
            try provider.getBooleanEvaluation(
                key: "archived",
                defaultValue: false,
                ctx: MutableContext(targetingKey: "user1")
            )
        ) { error in
            XCTAssertEqual(
                error as? OpenFeatureError, OpenFeatureError.flagNotFoundError(key: "archived"))
        }
    }
}
