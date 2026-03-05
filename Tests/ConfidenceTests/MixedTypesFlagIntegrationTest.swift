import Foundation
import XCTest

@testable import Confidence

@available(macOS 13.0, iOS 16.0, *)
class MixedTypesFlagIntegrationTest: XCTestCase {
    private var flagApplier = FlagApplierMock()

    override func setUp() {
        flagApplier = FlagApplierMock()
        super.setUp()
    }

    func testResolvesFlagWithMixedTypesAndNulls() async throws {
        class FakeClient: ConfidenceResolveClient {
            func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
                return .init(
                    resolvedValues: [
                        ResolvedValue(
                            variant: "flags/my-feature/variants/treatment",
                            value: .init(structure: [
                                "color": .init(string: "green"),
                                "size": .init(integer: 3),
                                "enabled": .init(null: ()),
                                "visible": .init(null: ())
                            ]),
                            flag: "my-feature",
                            resolveReason: .match,
                            shouldApply: true
                        )
                    ],
                    resolveToken: "token-1"
                )
            }
        }

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "test-user")])
            .withFlagResolverClient(flagResolver: FakeClient())
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()

        // String field
        let color = confidence.getEvaluation(key: "my-feature.color", defaultValue: "default")
        XCTAssertEqual("green", color.value)
        XCTAssertEqual(.match, color.reason)
        XCTAssertEqual("flags/my-feature/variants/treatment", color.variant)
        XCTAssertNil(color.errorCode)
        XCTAssertNil(color.errorMessage)

        // Integer field
        let size = confidence.getEvaluation(key: "my-feature.size", defaultValue: 0)
        XCTAssertEqual(3, size.value)
        XCTAssertEqual(.match, size.reason)
        XCTAssertNil(size.errorCode)

        // Null boolean fields — value is null, so default is returned
        let enabled = confidence.getEvaluation(key: "my-feature.enabled", defaultValue: false)
        XCTAssertEqual(false, enabled.value)
        XCTAssertEqual(.match, enabled.reason)
        XCTAssertEqual("flags/my-feature/variants/treatment", enabled.variant)

        let visible = confidence.getEvaluation(key: "my-feature.visible", defaultValue: false)
        XCTAssertEqual(false, visible.value)

        // Full flag as struct
        let fullFlag = confidence.getEvaluation(
            key: "my-feature",
            defaultValue: ConfidenceStruct()
        )
        XCTAssertEqual(.match, fullFlag.reason)
        XCTAssertNil(fullFlag.errorCode)
        let flagStruct = fullFlag.value
        XCTAssertEqual(flagStruct["color"], ConfidenceValue(string: "green"))
        XCTAssertEqual(flagStruct["size"], ConfidenceValue(integer: 3))
        XCTAssertEqual(flagStruct["enabled"], ConfidenceValue(null: ()))
        XCTAssertEqual(flagStruct["visible"], ConfidenceValue(null: ()))
    }

    func testNoAssignmentReturnsDefaults() async throws {
        class FakeClient: ConfidenceResolveClient {
            func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
                return .init(
                    resolvedValues: [
                        ResolvedValue(
                            flag: "my-feature",
                            resolveReason: .noSegmentMatch,
                            shouldApply: true
                        )
                    ],
                    resolveToken: "token-1"
                )
            }
        }

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "test-user")])
            .withFlagResolverClient(flagResolver: FakeClient())
            .withFlagApplier(flagApplier: flagApplier)
            .build()

        try await confidence.fetchAndActivate()

        let color = confidence.getEvaluation(key: "my-feature.color", defaultValue: "default")
        XCTAssertEqual("default", color.value)
        XCTAssertEqual(.noSegmentMatch, color.reason)
        XCTAssertNil(color.variant)
        XCTAssertNil(color.errorCode)
        XCTAssertNil(color.errorMessage)

        let size = confidence.getEvaluation(key: "my-feature.size", defaultValue: 0)
        XCTAssertEqual(0, size.value)
        XCTAssertEqual(.noSegmentMatch, size.reason)

        let enabled = confidence.getEvaluation(key: "my-feature.enabled", defaultValue: false)
        XCTAssertEqual(false, enabled.value)
        XCTAssertEqual(.noSegmentMatch, enabled.reason)
    }
}
