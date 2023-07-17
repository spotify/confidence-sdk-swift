import Foundation
import OpenFeature
import XCTest

@testable import ConfidenceProvider

// swiftlint:disable file_length
// swiftlint:disable type_body_length
@available(macOS 13.0, iOS 16.0, *)
class ConfidenceFeatureProviderTest: XCTestCase {
    private var flagApplier = FlagApplierMock()
    private let builder =
        ConfidenceFeatureProvider
        .Builder(credentials: .clientSecret(secret: "test"))
    private let cache = PersistentProviderCache.from(
        storage: StorageMock())

    override func setUp() {
        try? cache.clear()
        MockedConfidenceClientURLProtocol.reset()
        flagApplier = FlagApplierMock()

        super.setUp()
    }

    func testRefresh() async throws {
        var session = MockedConfidenceClientURLProtocol.mockedSession(flags: [:])
        let provider =
            builder
            .with(session: session)
            .with(flagApplier: flagApplier)
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

        let evaluationTask = Task {
            let evaluation = try provider.getIntegerEvaluation(
                key: "flag.size",
                defaultValue: 0,
                context: MutableContext(targetingKey: "user2"))

            XCTAssertEqual(evaluation.value, 3)
            XCTAssertNil(evaluation.errorCode)
            XCTAssertNil(evaluation.errorMessage)
            XCTAssertEqual(evaluation.reason, Reason.targetingMatch.rawValue)
            XCTAssertEqual(evaluation.variant, "control")
        }

        try await evaluationTask.value
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 2)
        XCTAssertEqual(flagApplier.applyCallCount, 1)
    }

    func testResolveIntegerFlag() async throws {
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
            .with(flagApplier: flagApplier)
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        let evaluationTask = Task {
            let evaluation = try provider.getIntegerEvaluation(
                key: "flag.size",
                defaultValue: 0,
                context: MutableContext(targetingKey: "user1"))

            XCTAssertEqual(evaluation.value, 3)
            XCTAssertNil(evaluation.errorCode)
            XCTAssertNil(evaluation.errorMessage)
            XCTAssertEqual(evaluation.reason, Reason.targetingMatch.rawValue)
            XCTAssertEqual(evaluation.variant, "control")
        }

        try await evaluationTask.value
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(flagApplier.applyCallCount, 1)
    }

    func testResolveAndApplyIntegerFlag() async throws {
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
            .with(flagApplier: flagApplier)
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        let evaluationTask = Task {
            let evaluation = try provider.getIntegerEvaluation(
                key: "flag.size",
                defaultValue: 1,
                context: MutableContext(targetingKey: "user1"))

            XCTAssertEqual(evaluation.value, 3)
            XCTAssertNil(evaluation.errorCode)
            XCTAssertNil(evaluation.errorMessage)
            XCTAssertEqual(evaluation.reason, Reason.targetingMatch.rawValue)
            XCTAssertEqual(evaluation.variant, "control")
        }

        try await evaluationTask.value

        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(flagApplier.applyCallCount, 1)
    }

    func testResolveAndApplyIntegerFlagNoSegmentMatch() async throws {
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
            .with(flagApplier: flagApplier)
            .build()

        let ctx = MutableContext(targetingKey: "user2")
        provider.initialize(initialContext: ctx)

        let evaluationTask = Task {
            let evaluation = try provider.getIntegerEvaluation(
                key: "flag.size",
                defaultValue: 1,
                context: MutableContext(targetingKey: "user2"))

            XCTAssertEqual(evaluation.value, 1)
            XCTAssertNil(evaluation.errorCode)
            XCTAssertNil(evaluation.errorMessage)
            XCTAssertEqual(evaluation.reason, Reason.defaultReason.rawValue)
            XCTAssertEqual(evaluation.variant, nil)
        }

        try await evaluationTask.value
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(flagApplier.applyCallCount, 1)
    }

    func testResolveAndApplyIntegerFlagTwice() async throws {
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
            .with(flagApplier: flagApplier)
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        let evaluationTask = Task {
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
        }

        try await evaluationTask.value
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(flagApplier.applyCallCount, 2)
    }

    func testResolveAndApplyIntegerFlagError() async throws {
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
            .with(flagApplier: flagApplier)
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        let evaluationTask = Task {
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
        }
        try await evaluationTask.value

        XCTAssertEqual(flagApplier.applyCallCount, 2)
    }

    func testStaleEvaluationContextInCache() async throws {
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

        let evaluationTask = Task {
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
        }
        try await evaluationTask.value
        XCTAssertEqual(flagApplier.applyCallCount, 0)
    }

    func testResolveDoubleFlag() async throws {
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
            .with(flagApplier: flagApplier)
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        let evaluationTask = Task {
            let evaluation = try provider.getDoubleEvaluation(
                key: "flag.size",
                defaultValue: 1.1,
                context: MutableContext(targetingKey: "user1"))

            XCTAssertEqual(evaluation.value, 3.1)
            XCTAssertNil(evaluation.errorCode)
            XCTAssertNil(evaluation.errorMessage)
            XCTAssertEqual(evaluation.reason, Reason.targetingMatch.rawValue)
            XCTAssertEqual(evaluation.variant, "control")
        }

        try await evaluationTask.value
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(flagApplier.applyCallCount, 1)
    }

    func testResolveBooleanFlag() async throws {
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
            .with(flagApplier: flagApplier)
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        let evaluationTask = Task {
            let evaluation = try provider.getBooleanEvaluation(
                key: "flag.visible",
                defaultValue: true,
                context: MutableContext(targetingKey: "user1"))

            XCTAssertEqual(evaluation.value, false)
            XCTAssertNil(evaluation.errorCode)
            XCTAssertNil(evaluation.errorMessage)
            XCTAssertEqual(evaluation.reason, Reason.targetingMatch.rawValue)
            XCTAssertEqual(evaluation.variant, "control")
        }

        try await evaluationTask.value
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(flagApplier.applyCallCount, 1)
    }

    func testResolveObjectFlag() async throws {
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
            .with(flagApplier: flagApplier)
            .build()

        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        let evaluationTask = Task {
            let evaluation = try provider.getObjectEvaluation(
                key: "flag",
                defaultValue: .structure(["size": .integer(0)]),
                context: MutableContext(targetingKey: "user1"))

            XCTAssertEqual(evaluation.value, .structure(["size": .integer(3)]))
            XCTAssertNil(evaluation.errorCode)
            XCTAssertNil(evaluation.errorMessage)
            XCTAssertEqual(evaluation.reason, Reason.targetingMatch.rawValue)
            XCTAssertEqual(evaluation.variant, "control")
        }

        try await evaluationTask.value
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(flagApplier.applyCallCount, 1)
    }

    func testResolveNullValues() async throws {
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
            .with(flagApplier: flagApplier)
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        let evaluationTask = Task {
            let evaluation = try provider.getIntegerEvaluation(
                key: "flag.size",
                defaultValue: 42,
                context: MutableContext(targetingKey: "user1"))

            XCTAssertEqual(evaluation.value, 42)
            XCTAssertNil(evaluation.errorCode)
            XCTAssertNil(evaluation.errorMessage)
            XCTAssertEqual(evaluation.reason, Reason.targetingMatch.rawValue)
            XCTAssertEqual(evaluation.variant, "control")
        }

        try await evaluationTask.value
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(flagApplier.applyCallCount, 1)
    }

    func testProviderThrowsFlagNotFound() async throws {
        let session = MockedConfidenceClientURLProtocol.mockedSession(flags: [:])
        let provider =
            builder
            .with(session: session)
            .with(cache: cache)
            .with(flagApplier: flagApplier)
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        let evaluationTask = Task {
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
        }

        try await evaluationTask.value
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(flagApplier.applyCallCount, 0)
    }

    func testProviderNoTargetingKey() async throws {
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
            .with(flagApplier: flagApplier)
            .build()

        // Note no context has been set via initialize or onContextSet

        let evaluationTask = Task {
            XCTAssertThrowsError(
                try provider.getIntegerEvaluation(
                    key: "flag.size",
                    defaultValue: 3,
                    context: nil)
            ) { error in
                XCTAssertEqual(
                    error as? OpenFeatureError, OpenFeatureError.invalidContextError)
            }
        }

        try await evaluationTask.value
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 0)
        XCTAssertEqual(flagApplier.applyCallCount, 0)
    }

    func testProviderTargetingKeyError() async throws {
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
            .with(flagApplier: flagApplier)
            .build()
        // note "custom_targeting_key" is treated specially in the MockedSession
        provider.initialize(
            initialContext: MutableContext(
                targetingKey: "user1",
                structure: MutableStructure(attributes: ["custom_targeting_key": Value.integer(2)])))

        let evaluationTask = Task {
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
        }

        try await evaluationTask.value
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(flagApplier.applyCallCount, 0)
    }

    func testProviderCannotParse() async throws {
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
            .with(flagApplier: flagApplier)
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        let evaluationTask = Task {
            XCTAssertThrowsError(
                try provider.getStringEvaluation(
                    key: "flag.size",
                    defaultValue: "value",
                    context: MutableContext(targetingKey: "user1"))
            ) { error in
                XCTAssertEqual(
                    error as? OpenFeatureError, OpenFeatureError.parseError(message: "Unable to parse flag value: 3"))
            }
        }

        try await evaluationTask.value
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(flagApplier.applyCallCount, 0)
    }

    func testLocalOverrideReplacesFlag() async throws {
        let resolve: [String: MockedConfidenceClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .integer(3)]))
        ]

        let flags: [String: MockedConfidenceClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let session = MockedConfidenceClientURLProtocol.mockedSession(flags: flags)
        let provider = builder.with(session: session)
            .with(flagApplier: flagApplier)
            .overrides(.flag(name: "flag", variant: "control", value: ["size": .integer(4)]))
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        let evaluationTask = Task {
            let evaluation = try provider.getIntegerEvaluation(
                key: "flag.size",
                defaultValue: 0,
                context: MutableContext(targetingKey: "user1"))

            XCTAssertEqual(evaluation.variant, "control")
            XCTAssertEqual(evaluation.reason, Reason.staticReason.rawValue)
            XCTAssertEqual(evaluation.value, 4)
        }

        try await evaluationTask.value
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(flagApplier.applyCallCount, 0)
    }

    func testLocalOverridePartiallyReplacesFlag() async throws {
        let resolve: [String: MockedConfidenceClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .integer(3), "color": .string("green")]))
        ]

        let flags: [String: MockedConfidenceClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let session = MockedConfidenceClientURLProtocol.mockedSession(flags: flags)
        let provider = builder.with(session: session)
            .with(flagApplier: flagApplier)
            .overrides(.field(path: "flag.size", variant: "treatment", value: .integer(4)))
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        let evaluationTask = Task {
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
        }

        try await evaluationTask.value
        XCTAssertEqual(flagApplier.applyCallCount, 1)
    }

    func testLocalOverrideNoEvaluationContext() async throws {
        let resolve: [String: MockedConfidenceClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .integer(3), "color": .string("green")]))
        ]

        let flags: [String: MockedConfidenceClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let session = MockedConfidenceClientURLProtocol.mockedSession(flags: flags)
        let provider = builder.with(session: session)
            .with(flagApplier: flagApplier)
            .overrides(.field(path: "flag.size", variant: "treatment", value: .integer(4)))
            .build()

        let evaluationTask = Task {
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
        }

        try await evaluationTask.value
        XCTAssertEqual(flagApplier.applyCallCount, 0)
    }

    func testLocalOverrideTwiceTakesSecondOverride() async throws {
        let resolve: [String: MockedConfidenceClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .integer(3)]))
        ]

        let flags: [String: MockedConfidenceClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let session = MockedConfidenceClientURLProtocol.mockedSession(flags: flags)
        let provider = builder.with(session: session)
            .with(flagApplier: flagApplier)
            .overrides(.field(path: "flag.size", variant: "control", value: .integer(4)))
            .overrides(.field(path: "flag.size", variant: "treatment", value: .integer(5)))
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        let evaluationTask = Task {
            let evaluation = try provider.getIntegerEvaluation(
                key: "flag.size",
                defaultValue: 0,
                context: MutableContext(targetingKey: "user1"))

            XCTAssertEqual(evaluation.variant, "treatment")
            XCTAssertEqual(evaluation.reason, Reason.staticReason.rawValue)
            XCTAssertEqual(evaluation.value, 5)
        }

        try await evaluationTask.value
        XCTAssertEqual(MockedConfidenceClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(flagApplier.applyCallCount, 0)
    }

    func testOverridingInProvider() async throws {
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
            .with(flagApplier: flagApplier)
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        provider.overrides(.field(path: "flag.size", variant: "treatment", value: .integer(5)))

        let evaluationTask = Task {
            let evaluation = try provider.getIntegerEvaluation(
                key: "flag.size",
                defaultValue: 0,
                context: MutableContext(targetingKey: "user1"))

            XCTAssertEqual(evaluation.variant, "treatment")
            XCTAssertEqual(evaluation.reason, Reason.staticReason.rawValue)
            XCTAssertEqual(evaluation.value, 5)
        }

        try await evaluationTask.value
        XCTAssertEqual(flagApplier.applyCallCount, 0)
    }
}

final class DispatchQueueFake: DispatchQueueType {
    var count = 0

    func async(execute work: @escaping @convention(block) () -> Void) {
        count += 1
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
