import Foundation
import OpenFeature
import XCTest

@testable import KonfidensProvider

// swiftlint:disable type_body_length
// swiftlint:disable file_length
@available(macOS 13.0, iOS 16.0, *)
class KonfidensFeatureProviderTest: XCTestCase {
    private let builder = KonfidensFeatureProvider.Builder(credentials: .clientSecret(secret: "test"))
    private let cache = PersistentProviderCache.fromDefaultStorage()

    override func setUp() {
        try? cache.clear()
        MockedKonfidensClientURLProtocol.reset()

        super.setUp()
    }

    func testRefresh() async throws {
        var session = MockedKonfidensClientURLProtocol.mockedSession(flags: [:])
        let provider = builder.with(session: session).build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        XCTAssertThrowsError(
            try provider.getStringEvaluation(
                key: "flag.size",
                defaultValue: "value")
        ) { error in
            XCTAssertEqual(
                error as? OpenFeatureError,
                OpenFeatureError.generalError(
                    message: "Error during string evaluation for key flag.size: Flag not found in the cache"))
        }

        let resolve: [String: MockedKonfidensClientURLProtocol.ResolvedTestFlag] = [
            "user2": .init(variant: "control", value: .structure(["size": .integer(3)]))
        ]

        let flags: [String: MockedKonfidensClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        session = MockedKonfidensClientURLProtocol.mockedSession(flags: flags)
        provider.onContextSet(
            oldContext: MutableContext(targetingKey: "user1"), newContext: MutableContext(targetingKey: "user2"))

        let evaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 0)

        XCTAssertEqual(evaluation.value, 3)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, Reason.targetingMatch.rawValue)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(MockedKonfidensClientURLProtocol.resolveStats, 2)
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
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        let evaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 0)

        XCTAssertEqual(evaluation.value, 3)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, Reason.targetingMatch.rawValue)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(MockedKonfidensClientURLProtocol.resolveStats, 1)
    }

    func testResolveAndApplyIntegerFlag() throws {
        let resolve: [String: MockedKonfidensClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .integer(3)]))
        ]

        let flags: [String: MockedKonfidensClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let session = MockedKonfidensClientURLProtocol.mockedSession(flags: flags)
        let provider =
            builder
            .with(session: session)
            .with(cache: cache)
            .with(applyQueue: DispatchQueueFake())

            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        XCTAssertEqual(
            try cache.getValue(flag: "flag", ctx: MutableContext(targetingKey: "user1"))?.resolvedValue.applyStatus,
            .notApplied)
        let evaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 1)
        XCTAssertEqual(
            try cache.getValue(flag: "flag", ctx: MutableContext(targetingKey: "user1"))?.resolvedValue.applyStatus,
            .applied)

        XCTAssertEqual(evaluation.value, 3)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, Reason.targetingMatch.rawValue)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(MockedKonfidensClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(MockedKonfidensClientURLProtocol.applyStats, 1)
    }

    func testResolveAndApplyIntegerFlagNoSegmentMatch() throws {
        let resolve: [String: MockedKonfidensClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .integer(3)]))
        ]

        let flags: [String: MockedKonfidensClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let session = MockedKonfidensClientURLProtocol.mockedSession(flags: flags)
        let provider =
            builder
            .with(session: session)
            .with(cache: cache)
            .with(applyQueue: DispatchQueueFake())
            .build()

        let ctx = MutableContext(targetingKey: "user2")
        provider.initialize(initialContext: ctx)

        XCTAssertEqual(
            try cache.getValue(flag: "flag", ctx: MutableContext(targetingKey: "user2"))?.resolvedValue.applyStatus,
            .notApplied)
        let evaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 1)
        XCTAssertEqual(
            try cache.getValue(flag: "flag", ctx: MutableContext(targetingKey: "user2"))?.resolvedValue.applyStatus,
            .applied)

        XCTAssertEqual(evaluation.value, 1)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, Reason.defaultReason.rawValue)
        XCTAssertEqual(evaluation.variant, nil)
        XCTAssertEqual(MockedKonfidensClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(MockedKonfidensClientURLProtocol.applyStats, 1)
    }

    func testResolveAndApplyIntegerFlagTwice() throws {
        let resolve: [String: MockedKonfidensClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .integer(3)]))
        ]

        let flags: [String: MockedKonfidensClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let session = MockedKonfidensClientURLProtocol.mockedSession(flags: flags)
        let provider =
            builder
            .with(session: session)
            .with(cache: cache)
            .with(applyQueue: DispatchQueueFake())
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        XCTAssertEqual(
            try cache.getValue(flag: "flag", ctx: MutableContext(targetingKey: "user1"))?.resolvedValue.applyStatus,
            .notApplied)
        let evaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 1)
        XCTAssertEqual(
            try cache.getValue(flag: "flag", ctx: MutableContext(targetingKey: "user1"))?.resolvedValue.applyStatus,
            .applied)
        _ = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 1)
        XCTAssertEqual(
            try cache.getValue(flag: "flag", ctx: MutableContext(targetingKey: "user1"))?.resolvedValue.applyStatus,
            .applied)

        XCTAssertEqual(evaluation.value, 3)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, Reason.targetingMatch.rawValue)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(MockedKonfidensClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(MockedKonfidensClientURLProtocol.applyStats, 1)
    }

    func testResolveAndApplyIntegerFlagTwiceSlow() throws {
        let resolve: [String: MockedKonfidensClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .integer(3)]))
        ]

        let flags: [String: MockedKonfidensClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let expectation = XCTestExpectation(description: "applied complete")
        let session = MockedKonfidensClientURLProtocol.mockedSession(flags: flags)
        let provider =
            builder
            .with(session: session)
            .with(cache: cache)
            .with(applyQueue: DispatchQueueFakeSlow(expectation: expectation))
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        XCTAssertEqual(
            try cache.getValue(flag: "flag", ctx: MutableContext(targetingKey: "user1"))?.resolvedValue.applyStatus,
            .notApplied)
        let evaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 1)
        _ = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 1)
        XCTAssertEqual(
            try cache.getValue(flag: "flag", ctx: MutableContext(targetingKey: "user1"))?.resolvedValue.applyStatus,
            .applying)

        XCTAssertEqual(evaluation.value, 3)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, Reason.targetingMatch.rawValue)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(MockedKonfidensClientURLProtocol.resolveStats, 1)
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(
            try cache.getValue(flag: "flag", ctx: MutableContext(targetingKey: "user1"))?.resolvedValue.applyStatus,
            .applied)
        XCTAssertEqual(MockedKonfidensClientURLProtocol.applyStats, 1)
    }

    func testResolveAndApplyIntegerFlagError() throws {
        let resolve: [String: MockedKonfidensClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .integer(3)]))
        ]

        let flags: [String: MockedKonfidensClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        MockedKonfidensClientURLProtocol.failFirstApply = true
        let session = MockedKonfidensClientURLProtocol.mockedSession(flags: flags)
        let provider =
            builder
            .with(session: session)
            .with(cache: cache)
            .with(applyQueue: DispatchQueueFake())
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        XCTAssertEqual(
            try cache.getValue(flag: "flag", ctx: MutableContext(targetingKey: "user1"))?.resolvedValue.applyStatus,
            .notApplied)
        let evaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 1)
        XCTAssertEqual(
            try cache.getValue(flag: "flag", ctx: MutableContext(targetingKey: "user1"))?.resolvedValue.applyStatus,
            .applyFailed)
        _ = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 1)
        XCTAssertEqual(
            try cache.getValue(flag: "flag", ctx: MutableContext(targetingKey: "user1"))?.resolvedValue.applyStatus,
            .applied)

        XCTAssertEqual(evaluation.value, 3)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, Reason.targetingMatch.rawValue)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(MockedKonfidensClientURLProtocol.resolveStats, 1)
        XCTAssertEqual(MockedKonfidensClientURLProtocol.applyStats, 2)
    }

    func testResolveDoubleFlag() throws {
        let resolve: [String: MockedKonfidensClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["size": .double(3.1)]))
        ]

        let flags: [String: MockedKonfidensClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let session = MockedKonfidensClientURLProtocol.mockedSession(flags: flags)
        let provider = builder.with(session: session).build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        let evaluation = try provider.getDoubleEvaluation(
            key: "flag.size",
            defaultValue: 1.1)

        XCTAssertEqual(evaluation.value, 3.1)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, Reason.targetingMatch.rawValue)
        XCTAssertEqual(evaluation.variant, "control")
    }

    func testResolveBooleanFlag() throws {
        let resolve: [String: MockedKonfidensClientURLProtocol.ResolvedTestFlag] = [
            "user1": .init(variant: "control", value: .structure(["visible": .boolean(false)]))
        ]

        let flags: [String: MockedKonfidensClientURLProtocol.TestFlag] = [
            "flags/flag": .init(resolve: resolve)
        ]

        let session = MockedKonfidensClientURLProtocol.mockedSession(flags: flags)
        let provider = builder.with(session: session).build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        let evaluation = try provider.getBooleanEvaluation(
            key: "flag.visible",
            defaultValue: true)

        XCTAssertEqual(evaluation.value, false)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, Reason.targetingMatch.rawValue)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(MockedKonfidensClientURLProtocol.resolveStats, 1)
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

        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))
        let evaluation = try provider.getObjectEvaluation(
            key: "flag",
            defaultValue: .structure(["size": .integer(0)]))

        XCTAssertEqual(evaluation.value, .structure(["size": .integer(3)]))
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, Reason.targetingMatch.rawValue)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(MockedKonfidensClientURLProtocol.resolveStats, 1)
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
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        let evaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 42)

        XCTAssertEqual(evaluation.value, 42)
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.reason, Reason.targetingMatch.rawValue)
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(MockedKonfidensClientURLProtocol.resolveStats, 1)
    }

    func testProviderThrowsFlagNotFound() throws {
        let session = MockedKonfidensClientURLProtocol.mockedSession(flags: [:])
        let provider =
            builder
            .with(session: session)
            .with(cache: cache)
            .build()
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        XCTAssertThrowsError(
            try provider.getObjectEvaluation(
                key: "flag",
                defaultValue: .structure(["size": .integer(0)]))
        ) { error in
            XCTAssertEqual(
                error as? OpenFeatureError,
                OpenFeatureError.generalError(
                    message: "Error during object evaluation for key flag: Flag not found in the cache"))
        }
        XCTAssertEqual(MockedKonfidensClientURLProtocol.resolveStats, 1)
    }

    func testProviderNoTargetingKey() throws {
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
        provider.initialize(initialContext: MutableContext(attributes: [:]))

        let evaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 3)
        XCTAssertEqual(MockedKonfidensClientURLProtocol.resolveStats, 1)
        XCTAssertNil(evaluation.variant)
        XCTAssertEqual(evaluation.reason, Reason.defaultReason.rawValue)
        XCTAssertEqual(evaluation.value, 3)
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
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        XCTAssertThrowsError(
            try provider.getStringEvaluation(
                key: "flag.size",
                defaultValue: "value")
        ) { error in
            XCTAssertEqual(
                error as? OpenFeatureError, OpenFeatureError.parseError(message: "Unable to parse flag value: 3"))
        }
        XCTAssertEqual(MockedKonfidensClientURLProtocol.resolveStats, 1)
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
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        let evaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 0)

        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(evaluation.reason, Reason.defaultReason.rawValue)
        XCTAssertEqual(evaluation.value, 4)
        XCTAssertEqual(MockedKonfidensClientURLProtocol.resolveStats, 1)
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
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        let sizeEvaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 0)

        XCTAssertEqual(sizeEvaluation.variant, "treatment")
        XCTAssertEqual(sizeEvaluation.reason, Reason.defaultReason.rawValue)
        XCTAssertEqual(sizeEvaluation.value, 4)

        let colorEvaluation = try provider.getStringEvaluation(
            key: "flag.color",
            defaultValue: "blue")

        XCTAssertEqual(colorEvaluation.variant, "control")
        XCTAssertEqual(colorEvaluation.reason, Reason.targetingMatch.rawValue)
        XCTAssertEqual(colorEvaluation.value, "green")
        XCTAssertEqual(MockedKonfidensClientURLProtocol.resolveStats, 1)
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
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        let evaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 0)

        XCTAssertEqual(evaluation.variant, "treatment")
        XCTAssertEqual(evaluation.reason, Reason.defaultReason.rawValue)
        XCTAssertEqual(evaluation.value, 5)
        XCTAssertEqual(MockedKonfidensClientURLProtocol.resolveStats, 1)
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
        provider.initialize(initialContext: MutableContext(targetingKey: "user1"))

        provider.overrides(.field(path: "flag.size", variant: "treatment", value: .integer(5)))

        let evaluation = try provider.getIntegerEvaluation(
            key: "flag.size",
            defaultValue: 0)

        XCTAssertEqual(evaluation.variant, "treatment")
        XCTAssertEqual(evaluation.reason, Reason.defaultReason.rawValue)
        XCTAssertEqual(evaluation.value, 5)
    }
}

final class DispatchQueueFake: DispatchQueueType {
    func async(execute work: @escaping @convention(block) () -> Void) {
        work()
    }
}

@available(macOS 13.0, iOS 16.0, *)
final class DispatchQueueFakeSlow: DispatchQueueType {
    var expectation: XCTestExpectation
    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }
    func async(execute work: @escaping @convention(block) () -> Void) {
        Task {
            try await Task.sleep(for: Duration.seconds(1))
            work()
            expectation.fulfill()
        }
    }
}
