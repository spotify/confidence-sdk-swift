import Foundation
import ConfidenceProvider
import Combine
import OpenFeature
import XCTest

@testable import Confidence

@available(macOS 13.0, iOS 16.0, *)
class MixedTypesFlagOpenFeatureIntegrationTest: XCTestCase {
    override func setUp() {
        super.setUp()
        OpenFeatureAPI.shared.clearProvider()
    }

    private func createMixedTypesClient() -> ConfidenceResolveClient {
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
        return FakeClient()
    }

    private func setupProvider(confidence: Confidence) async -> AnyCancellable {
        let readyExpectation = XCTestExpectation(description: "Ready")
        let provider = ConfidenceFeatureProvider(
            confidence: confidence,
            initializationStrategy: .fetchAndActivate
        )
        let cancellable = OpenFeatureAPI.shared.observe().sink { event in
            if event == .ready() {
                readyExpectation.fulfill()
            }
        }
        OpenFeatureAPI.shared.setProvider(provider: provider)
        await fulfillment(of: [readyExpectation], timeout: 5.0)
        return cancellable
    }

    func testResolvesFlagWithMixedTypesAndNulls() async throws {
        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "test-user")])
            .withFlagResolverClient(flagResolver: createMixedTypesClient())
            .build()

        let cancellable = await setupProvider(confidence: confidence)
        let client = OpenFeatureAPI.shared.getClient()

        // String field
        let color = client.getStringDetails(key: "my-feature.color", defaultValue: "default")
        XCTAssertEqual("green", color.value)
        XCTAssertEqual("RESOLVE_REASON_MATCH", color.reason)
        XCTAssertEqual("flags/my-feature/variants/treatment", color.variant)
        XCTAssertNil(color.errorCode)

        // Integer field
        let size = client.getIntegerDetails(key: "my-feature.size", defaultValue: 0)
        XCTAssertEqual(3, size.value)
        XCTAssertEqual("RESOLVE_REASON_MATCH", size.reason)
        XCTAssertNil(size.errorCode)

        // Null boolean fields — default returned since value is null
        let enabled = client.getBooleanDetails(key: "my-feature.enabled", defaultValue: false)
        XCTAssertEqual(false, enabled.value)
        XCTAssertEqual("RESOLVE_REASON_MATCH", enabled.reason)

        let visible = client.getBooleanDetails(key: "my-feature.visible", defaultValue: false)
        XCTAssertEqual(false, visible.value)

        // Full flag as object with populated defaults
        let defaultStructure = Value.structure([
            "color": .string("default"),
            "size": .integer(0),
            "enabled": .boolean(false),
            "visible": .boolean(false)
        ])
        let fullFlag = client.getObjectDetails(
            key: "my-feature", defaultValue: defaultStructure)
        XCTAssertEqual("RESOLVE_REASON_MATCH", fullFlag.reason)
        XCTAssertNil(fullFlag.errorCode)
        guard case let .structure(flagStruct) = fullFlag.value else {
            XCTFail("Expected structure value")
            return
        }
        XCTAssertEqual(flagStruct["color"], .string("green"))
        XCTAssertEqual(flagStruct["size"], .integer(3))
        // Null boolean fields — default returned since value is null
        XCTAssertEqual(flagStruct["enabled"], .boolean(false))
        XCTAssertEqual(flagStruct["visible"], .boolean(false))

        cancellable.cancel()
    }

    func testGetObjectDetailsWithEmptyDefaultStruct() async throws {
        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "test-user")])
            .withFlagResolverClient(flagResolver: createMixedTypesClient())
            .build()

        let cancellable = await setupProvider(confidence: confidence)
        let client = OpenFeatureAPI.shared.getClient()

        // Full flag as object with empty default — should not cause parseError
        let fullFlag = client.getObjectDetails(
            key: "my-feature", defaultValue: Value.structure([:]))
        XCTAssertEqual("RESOLVE_REASON_MATCH", fullFlag.reason)
        XCTAssertNil(fullFlag.errorCode)
        guard case let .structure(flagStruct) = fullFlag.value else {
            XCTFail("Expected structure value")
            return
        }
        XCTAssertEqual(flagStruct["color"], .string("green"))
        XCTAssertEqual(flagStruct["size"], .integer(3))
        XCTAssertEqual(flagStruct["enabled"], .null)
        XCTAssertEqual(flagStruct["visible"], .null)

        cancellable.cancel()
    }

    private func createNoAssignmentClient() -> ConfidenceResolveClient {
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
        return FakeClient()
    }

    func testNoAssignmentReturnsDefaults() async throws {
        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "test-user")])
            .withFlagResolverClient(flagResolver: createNoAssignmentClient())
            .build()

        let cancellable = await setupProvider(confidence: confidence)
        let client = OpenFeatureAPI.shared.getClient()

        let color = client.getStringDetails(key: "my-feature.color", defaultValue: "default")
        XCTAssertEqual("default", color.value)
        XCTAssertEqual("RESOLVE_REASON_NO_SEGMENT_MATCH", color.reason)
        XCTAssertNil(color.variant)
        XCTAssertNil(color.errorCode)

        let size = client.getIntegerDetails(key: "my-feature.size", defaultValue: 0)
        XCTAssertEqual(0, size.value)
        XCTAssertEqual("RESOLVE_REASON_NO_SEGMENT_MATCH", size.reason)

        let enabled = client.getBooleanDetails(key: "my-feature.enabled", defaultValue: false)
        XCTAssertEqual(false, enabled.value)
        XCTAssertEqual("RESOLVE_REASON_NO_SEGMENT_MATCH", enabled.reason)

        cancellable.cancel()
    }
}
