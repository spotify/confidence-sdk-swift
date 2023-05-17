import Foundation
import OpenFeature
import XCTest

@testable import ConfidenceProvider

// swiftlint:disable type_body_length
// swiftlint:disable file_length
@available(macOS 13.0, iOS 16.0, *)
class ConfidenceFeatureProviderTest: XCTestCase {
    private let builder =
        ConfidenceFeatureProvider
        .Builder(credentials: .clientSecret(secret: "test"))
        .with(applyQueue: DispatchQueueFake())
    private let cache = PersistentProviderCache.fromDefaultStorage()

    override func setUp() {
        try? cache.clear()
        MockedConfidenceClientURLProtocol.reset()

        super.setUp()
    }

    func testRefresh() async throws {
        var session = MockedConfidenceClientURLProtocol.mockedSession(flags: [:])
        let provider =
            builder
            .with(session: session)
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        XCTAssertThrowsError(
            try provider.getStringEvaluation(
                key: "flag.size",
                defaultValue: "value",
                context: MutableContext(targetingKey: "user1"))
        ) { error in
            XCTAssertEqual(
                error as? OpenFeatureError,
                OpenFeatureError.flagNotFoundError(key: "flag"))
        }

        let resolve: [String: MockedConfidenceClientURLProtocol.ResolvedTestFlag] = [
            "user2": .init(variant: "control", value: .structure(["size": .integer(3)]))
        ]

        let flags: [String: MockedConfidenceClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        session = MockedConfidenceClientURLProtocol.mockedSession(flags: flags)
        provider.onContextSet(
            oldContext: MutableContext(targetingKey: "user1"), newContext: MutableContext(targetingKey: "user2"))

        let evaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 0,
            context: MutableContext(targetingKey: "user2"))

        XCTAssertEqual(evaluation.value, 3)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, Reason.targetingMatch.rawValue)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 2)
        XCTAssertEqual(MockedConfidenceClientURLProtocol.applyStats, 1)
    }

    func testResolveIntegerFlag() throws {
        let resolve: [String: MockedConfidenceClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .integer(3)]))
        ]

        let flags: [String: MockedConfidenceClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let session = MockedConfidenceClientURLProtocol.mockedSession(flags: flags)
        let provider =
            builder
            .with(session: session)
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        let evaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 0,
            context: MutableContext(targetingKey: "user1"))

        XCTAssertEqual(evaluation.value, 3)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, Reason.targetingMatch.rawValue)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(MockedConfidenceClientURLProtocol.applyStats, 1)
    }

    func testResolveAndApplyIntegerFlag() throws {
        let resolve: [String: MockedConfidenceClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .integer(3)]))
        ]

        let flags: [String: MockedConfidenceClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let session = MockedConfidenceClientURLProtocol.mockedSession(flags: flags)
        let provider =
            builder
            .with(session: session)
            .with(cache: cache)
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        let evaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 1,
            context: MutableContext(targetingKey: "user1"))

        XCTAssertEqual(evaluation.value, 3)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, Reason.targetingMatch.rawValue)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(MockedConfidenceClientURLProtocol.applyStats, 1)
    }

    func testResolveAndApplyIntegerFlagNoSegmentMatch() throws {
        let resolve: [String: MockedConfidenceClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .integer(3)]))
        ]

        let flags: [String: MockedConfidenceClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let session = MockedConfidenceClientURLProtocol.mockedSession(flags: flags)
        let provider =
            builder
            .with(session: session)
            .with(cache: cache)
            .build()

        let ctx = MutableContext(targetingKey: "user2")
        provider.initialize(initialContext: ctx)
        let evaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 1,
            context: MutableContext(targetingKey: "user2"))

        XCTAssertEqual(evaluation.value, 1)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, Reason.defaultReason.rawValue)
        XCTAssertEqual(evaluation.variant, nil)
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(MockedConfidenceClientURLProtocol.applyStats, 1)
    }

    func testResolveAndApplyIntegerFlagTwice() throws {
        let resolve: [String: MockedConfidenceClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .integer(3)]))
        ]

        let flags: [String: MockedConfidenceClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let session = MockedConfidenceClientURLProtocol.mockedSession(flags: flags)
        let provider =
            builder
            .with(session: session)
            .with(cache: cache)
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        let evaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 1,
            context: MutableContext(targetingKey: "user1"))
        _ = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 1,
            context: MutableContext(targetingKey: "user1"))

        XCTAssertEqual(evaluation.value, 3)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, Reason.targetingMatch.rawValue)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(MockedConfidenceClientURLProtocol.applyStats, 2)
    }

    func testResolveAndApplyIntegerFlagTwiceSlow() throws {
        let resolve: [String: MockedConfidenceClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .integer(3)]))
        ]

        let flags: [String: MockedConfidenceClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let expectation = XCTestExpectation(description: "applied complete")
        let session = MockedConfidenceClientURLProtocol.mockedSession(flags: flags)
        let provider =
            builder
            .with(session: session)
            .with(cache: cache)
            .with(applyQueue: DispatchQueueFakeSlow(expectation: expectation))
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        let evaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 1,
            context: MutableContext(targetingKey: "user1"))
        _ = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 1,
            context: MutableContext(targetingKey: "user1"))

        XCTAssertEqual(evaluation.value, 3)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, Reason.targetingMatch.rawValue)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 1)
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(MockedConfidenceClientURLProtocol.applyStats, 2)
    }

    func testResolveAndApplyIntegerFlagError() throws {
        let resolve: [String: MockedConfidenceClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .integer(3)]))
        ]

        let flags: [String: MockedConfidenceClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        MockedConfidenceClientURLProtocol.failFirstApply = true
        let session = MockedConfidenceClientURLProtocol.mockedSession(flags: flags)
        let provider =
            builder
            .with(session: session)
            .with(cache: cache)
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        let evaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 1,
            context: MutableContext(targetingKey: "user1"))
        _ = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 1,
            context: MutableContext(targetingKey: "user1"))

        XCTAssertEqual(evaluation.value, 3)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, Reason.targetingMatch.rawValue)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(MockedConfidenceClientURLProtocol.applyStats, 2)
    }

    func testStaleEvaluationContextInCache() throws {
        let resolve: [String: MockedConfidenceClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .integer(3)]))
        ]

        let flags: [String: MockedConfidenceClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let session = MockedConfidenceClientURLProtocol.mockedSession(flags: flags)
        let provider =
            builder
            .with(session: session)
            .with(cache: cache)
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        // Simulating a cache with an old evaluation context
        try cache.clearAndSetValues(
            values: [ResolvedValue(flag: "flag", resolveReason: .match)],
            ctx: MutableContext(targetingKey: "user0"),
            resolveToken: "token0")

        let evaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 0,
            context: MutableContext(targetingKey: "user1"))

        XCTAssertEqual(evaluation.value, 0)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertNil(evaluation.variant)
        XCTAssertEqual(evaluation.reason, Reason.stale.rawValue)
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(MockedConfidenceClientURLProtocol.applyStats, 0)
    }

    func testResolveDoubleFlag() throws {
        let resolve: [String: MockedConfidenceClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .double(3.1)]))
        ]

        let flags: [String: MockedConfidenceClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let session = MockedConfidenceClientURLProtocol.mockedSession(flags: flags)
        let provider =
            builder
            .with(session: session)
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        let evaluation = try provider.getDoubleEvaluation(
            key: "flag.size",
            defaultValue: 1.1,
            context: MutableContext(targetingKey: "user1"))

        XCTAssertEqual(evaluation.value, 3.1)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, Reason.targetingMatch.rawValue)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(MockedConfidenceClientURLProtocol.applyStats, 1)
    }

    func testResolveBooleanFlag() throws {
        let resolve: [String: MockedConfidenceClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["visible": .boolean(false)]))
        ]

        let flags: [String: MockedConfidenceClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let session = MockedConfidenceClientURLProtocol.mockedSession(flags: flags)
        let provider =
            builder
            .with(session: session)
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        let evaluation = try provider.getBooleanEvaluation(
            key: "flag.visible",
            defaultValue: true,
            context: MutableContext(targetingKey: "user1"))

        XCTAssertEqual(evaluation.value, false)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, Reason.targetingMatch.rawValue)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(MockedConfidenceClientURLProtocol.applyStats, 1)
    }

    func testResolveObjectFlag() throws {
        let resolve: [String: MockedConfidenceClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .integer(3)]))
        ]

        let flags: [String: MockedConfidenceClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let session = MockedConfidenceClientURLProtocol.mockedSession(flags: flags)
        let provider =
            builder
            .with(session: session)
            .build()

        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))
        let evaluation = try provider.getObjectEvaluation(
            key: "flag",
            defaultValue: .structure(["size": .integer(0)]),
            context: MutableContext(targetingKey: "user1"))

        XCTAssertEqual(evaluation.value, .structure(["size": .integer(3)]))
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, Reason.targetingMatch.rawValue)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(MockedConfidenceClientURLProtocol.applyStats, 1)
    }

    func testResolveNullValues() throws {
        let resolve: [String: MockedConfidenceClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .null]))
        ]

        let schemas: [String: StructFlagSchema] = [
            "user1": .init(schema: ["size": .intSchema])
        ]

        let flags: [String: MockedConfidenceClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve, schemas: schemas)
        ]

        let session = MockedConfidenceClientURLProtocol.mockedSession(flags: flags)
        let provider =
            builder
            .with(session: session)
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        let evaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 42,
            context: MutableContext(targetingKey: "user1"))

        XCTAssertEqual(evaluation.value, 42)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, Reason.targetingMatch.rawValue)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(MockedConfidenceClientURLProtocol.applyStats, 1)
    }

    func testProviderThrowsFlagNotFound() throws {
        let session = MockedConfidenceClientURLProtocol.mockedSession(flags: [:])
        let provider =
            builder
            .with(session: session)
            .with(cache: cache)
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        XCTAssertThrowsError(
            try provider.getObjectEvaluation(
                key: "flag",
                defaultValue: .structure(["size": .integer(0)]),
                context: MutableContext(targetingKey: "user1"))
        ) { error in
            XCTAssertEqual(
                error as? OpenFeatureError,
                OpenFeatureError.flagNotFoundError(key: "flag"))
        }
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(MockedConfidenceClientURLProtocol.applyStats, 0)
    }

    func testProviderNoTargetingKey() throws {
        let resolve: [String: MockedConfidenceClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .null]))
        ]

        let schemas: [String: StructFlagSchema] = [
            "user1": .init(schema: ["size": .intSchema])
        ]

        let flags: [String: MockedConfidenceClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve, schemas: schemas)
        ]

        let session = MockedConfidenceClientURLProtocol.mockedSession(flags: flags)
        let provider =
            builder
            .with(session: session)
            .build()

        // Note no context has been set via initialize or onContextSet

        XCTAssertThrowsError(
            try provider.getIntegerEvaluation(
                key: "flag.size",
                defaultValue: 3,
                context: nil)
        ) { error in
            XCTAssertEqual(
                error as? OpenFeatureError, OpenFeatureError.invalidContextError)
        }
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 0)
        XCTAssertEqual(MockedConfidenceClientURLProtocol.applyStats, 0)
    }

    func testProviderTargetingKeyError() throws {
        let resolve: [String: MockedConfidenceClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .integer(3)]))
        ]

        let flags: [String: MockedConfidenceClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let session = MockedConfidenceClientURLProtocol.mockedSession(flags: flags)
        let provider =
            builder
            .with(session: session)
            .build()
        // note "custom_targeting_key" is treated specially in the MockedSession
        provider.initialize(
            initialContext: MutableContext(
                targetingKey: "user1",
                structure: MutableStructure(attributes: ["custom_targeting_key": Value.integer(2)])))

        let evaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 1,
            context: MutableContext(
                targetingKey: "user1",
                structure: MutableStructure(attributes: ["custom_targeting_key": Value.integer(2)])))
        XCTAssertEqual(evaluation.value, 1)
        XCTAssertNil(evaluation.variant)
        XCTAssertEqual(evaluation.errorCode, ErrorCode.invalidContext)
        XCTAssertEqual(evaluation.errorMessage, "Invalid targeting key")
        XCTAssertEqual(evaluation.reason, Reason.error.rawValue)
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(MockedConfidenceClientURLProtocol.applyStats, 0)
    }

    func testProviderCannotParse() throws {
        let resolve: [String: MockedConfidenceClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .integer(3)]))
        ]

        let flags: [String: MockedConfidenceClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let session = MockedConfidenceClientURLProtocol.mockedSession(flags: flags)
        let provider =
            builder
            .with(session: session)
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        XCTAssertThrowsError(
            try provider.getStringEvaluation(
                key: "flag.size",
                defaultValue: "value",
                context: MutableContext(targetingKey: "user1"))
        ) { error in
            XCTAssertEqual(
                error as? OpenFeatureError, OpenFeatureError.parseError(message: "Unable to parse flag value: 3"))
        }
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(MockedConfidenceClientURLProtocol.applyStats, 0)
    }

    func testLocalOverrideReplacesFlag() throws {
        let resolve: [String: MockedConfidenceClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .integer(3)]))
        ]

        let flags: [String: MockedConfidenceClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let session = MockedConfidenceClientURLProtocol.mockedSession(flags: flags)
        let provider = builder.with(session: session)
            .overrides(.flag(name: "flag", variant: "control", value: ["size": .integer(4)]))
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        let evaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 0,
            context: MutableContext(targetingKey: "user1"))

        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(evaluation.reason, Reason.staticReason.rawValue)
        XCTAssertEqual(evaluation.value, 4)
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(MockedConfidenceClientURLProtocol.applyStats, 0)
    }

    func testLocalOverridePartiallyReplacesFlag() throws {
        let resolve: [String: MockedConfidenceClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .integer(3), "color": .string("green")]))
        ]

        let flags: [String: MockedConfidenceClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let session = MockedConfidenceClientURLProtocol.mockedSession(flags: flags)
        let provider = builder.with(session: session)
            .overrides(.field(path: "flag.size", variant: "treatment", value: .integer(4)))
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        let sizeEvaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 0,
            context: MutableContext(targetingKey: "user1"))

        XCTAssertEqual(sizeEvaluation.variant, "treatment")
        XCTAssertEqual(sizeEvaluation.reason, Reason.staticReason.rawValue)
        XCTAssertEqual(sizeEvaluation.value, 4)

        let colorEvaluation = try provider.getStringEvaluation(
            key: "flag.color",
            defaultValue: "blue",
            context: MutableContext(targetingKey: "user1"))

        XCTAssertEqual(colorEvaluation.variant, "control")
        XCTAssertEqual(colorEvaluation.reason, Reason.targetingMatch.rawValue)
        XCTAssertEqual(colorEvaluation.value, "green")
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(MockedConfidenceClientURLProtocol.applyStats, 1)
    }

    func testLocalOverrideNoEvaluationContext() throws {
        let resolve: [String: MockedConfidenceClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .integer(3), "color": .string("green")]))
        ]

        let flags: [String: MockedConfidenceClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let session = MockedConfidenceClientURLProtocol.mockedSession(flags: flags)
        let provider = builder.with(session: session)
            .overrides(.field(path: "flag.size", variant: "treatment", value: .integer(4)))
            .build()

        let sizeEvaluation1 = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 0,
            context: nil)

        XCTAssertEqual(sizeEvaluation1.variant, "treatment")
        XCTAssertEqual(sizeEvaluation1.reason, Reason.staticReason.rawValue)
        XCTAssertEqual(sizeEvaluation1.value, 4)

        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        let sizeEvaluation2 = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 0,
            context: MutableContext(targetingKey: "user1"))

        XCTAssertEqual(sizeEvaluation2.variant, "treatment")
        XCTAssertEqual(sizeEvaluation2.reason, Reason.staticReason.rawValue)
        XCTAssertEqual(sizeEvaluation2.value, 4)
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(MockedConfidenceClientURLProtocol.applyStats, 0)
    }

    func testLocalOverrideTwiceTakesSecondOverride() throws {
        let resolve: [String: MockedConfidenceClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .integer(3)]))
        ]

        let flags: [String: MockedConfidenceClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let session = MockedConfidenceClientURLProtocol.mockedSession(flags: flags)
        let provider = builder.with(session: session)
            .overrides(.field(path: "flag.size", variant: "control", value: .integer(4)))
            .overrides(.field(path: "flag.size", variant: "treatment", value: .integer(5)))
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        let evaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 0,
            context: MutableContext(targetingKey: "user1"))

        XCTAssertEqual(evaluation.variant, "treatment")
        XCTAssertEqual(evaluation.reason, Reason.staticReason.rawValue)
        XCTAssertEqual(evaluation.value, 5)
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(MockedConfidenceClientURLProtocol.applyStats, 0)
    }

    func testOverridingInProvider() throws {
        let resolve: [String: MockedConfidenceClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .integer(3)]))
        ]

        let flags: [String: MockedConfidenceClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let session = MockedConfidenceClientURLProtocol.mockedSession(flags: flags)
        let provider =
            builder
            .with(session: session)
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        provider.overrides(.field(path: "flag.size", variant: "treatment", value: .integer(5)))

        let evaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 0,
            context: MutableContext(targetingKey: "user1"))

        XCTAssertEqual(evaluation.variant, "treatment")
        XCTAssertEqual(evaluation.reason, Reason.staticReason.rawValue)
        XCTAssertEqual(evaluation.value, 5)
        XCTAssertEqual(MockedConfidenceClientURLProtocol.applyStats, 0)
    }
}

final class DispatchQueueFake: DispatchQueueType {
    func async(execute work: @escaping @convention(block) () -> Void) {
        work()
    }
}

final class DispatchQueueFakeSlow: DispatchQueueType {
    var expectation: XCTestExpectation
    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }
    func async(execute work: @escaping @convention(block) () -> Void) {
        Task {
            try await Task.sleep(nanoseconds: 1 * 1_000_000_000)
            work()
            expectation.fulfill()
        }
    }
}
