import Foundation
import KonfidensProvider
import OpenFeature
import XCTest

class Konfidens: XCTestCase {
    override func setUp() {
        try? PersistentBatchProviderCache.fromDefaultStorage().clear()

        super.setUp()
    }

    func testKonfidensFeatureIntegration() throws {
        OpenFeatureAPI.shared.provider =
            KonfidensFeatureProvider.Builder(credentials: .clientSecret(secret: "<SECRET>"))
            .build()
        let client = OpenFeatureAPI.shared.getClient()

        let ctx = MutableContext(
            targetingKey: "user_foo",
            structure: MutableStructure(attributes: ["user": Value.structure(["country": Value.string("SE")])]))

        let intResult = client.getIntegerDetails(key: "test-flag-1.my-integer", defaultValue: 1, ctx: ctx)
        let boolResult = client.getBooleanDetails(key: "test-flag-1.my-boolean", defaultValue: false, ctx: ctx)

        XCTAssertEqual(intResult.flagKey, "test-flag-1.my-integer")
        XCTAssertEqual(intResult.reason, Reason.targetingMatch.rawValue)
        XCTAssertNotNil(intResult.variant)
        XCTAssertNil(intResult.errorCode)
        XCTAssertNil(intResult.errorMessage)
        XCTAssertEqual(boolResult.flagKey, "test-flag-1.my-boolean")
        XCTAssertEqual(boolResult.reason, Reason.targetingMatch.rawValue)
        XCTAssertNotNil(boolResult.variant)
        XCTAssertNil(boolResult.errorCode)
        XCTAssertNil(boolResult.errorMessage)
    }

    func testKonfidensBatchFeatureIntegration() throws {
        let konfidensFeatureProvider = KonfidensBatchFeatureProvider.Builder(
            credentials: .clientSecret(secret: "<SECRET>")
        )
        .build()

        OpenFeatureAPI.shared.provider = konfidensFeatureProvider

        let ctx = MutableContext(
            targetingKey: "user_foo",
            structure: MutableStructure(attributes: ["user": Value.structure(["country": Value.string("SE")])]))
        try konfidensFeatureProvider.initializeFromContext(ctx: ctx)

        let client = OpenFeatureAPI.shared.getClient()
        let result = client.getIntegerDetails(key: "test-flag-1.my-integer", defaultValue: 1, ctx: ctx)

        XCTAssertEqual(result.reason, Reason.targetingMatch.rawValue)
        XCTAssertNotNil(result.variant)
        XCTAssertNil(result.errorCode)
        XCTAssertNil(result.errorMessage)
    }

    func testKonfidensBatchFeatureProviderInvalidContext() throws {
        let konfidensFeatureProvider = KonfidensBatchFeatureProvider.Builder(
            credentials: .clientSecret(secret: "<SECRET>")
        )
        .build()

        OpenFeatureAPI.shared.provider = konfidensFeatureProvider

        let ctx = MutableContext(
            targetingKey: "user_foo",
            structure: MutableStructure(attributes: ["user": Value.structure(["country": Value.string("SE")])]))
        try konfidensFeatureProvider.initializeFromContext(ctx: ctx)

        let ctx2 = MutableContext(
            targetingKey: "user_foo",
            structure: MutableStructure(attributes: [
                "user": Value.structure(["country": Value.string("SE"), "premium": Value.boolean(true)])
            ]))
        let client = OpenFeatureAPI.shared.getClient()
        let result = client.getIntegerDetails(key: "test-flag-1.my-integer", defaultValue: 1, ctx: ctx2)

        XCTAssertEqual(result.value, 1)
        XCTAssertNil(result.variant)
        XCTAssertEqual(result.reason, Reason.error.rawValue)
        XCTAssertNotNil(result.errorCode)
        XCTAssertEqual(
            result.errorMessage,
            "General error: Error during integer evaluation for key test-flag-1.my-integer: Cached flag has an old evaluation context"
        )
    }

    func testKonfidensBatchFeatureIntegrationNoSegmentMatch() throws {
        let konfidensFeatureProvider = KonfidensBatchFeatureProvider.Builder(
            credentials: .clientSecret(secret: "<SECRET>")
        )
        .build()

        OpenFeatureAPI.shared.provider = konfidensFeatureProvider

        let ctx = MutableContext(
            targetingKey: "user_foo",
            structure: MutableStructure(attributes: ["user": Value.structure(["country": Value.string("IT")])]))
        try konfidensFeatureProvider.initializeFromContext(ctx: ctx)

        let client = OpenFeatureAPI.shared.getClient()
        let result = client.getIntegerDetails(key: "test-flag-1.my-integer", defaultValue: 1, ctx: ctx)

        XCTAssertEqual(result.value, 1)
        XCTAssertNil(result.variant)
        XCTAssertEqual(result.reason, Reason.defaultReason.rawValue)
        XCTAssertNil(result.errorCode)
        XCTAssertNil(result.errorMessage)
    }
}
