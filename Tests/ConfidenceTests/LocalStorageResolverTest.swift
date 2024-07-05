import Foundation
import XCTest

@testable import Confidence

class LocalStorageResolverTest: XCTestCase {
    func testStaleValueFromCache() throws {
        let resolvedValue = ResolvedValue(
            value: .init(structure: ["string": .init(string: "Value")]),
            flag: "flag_name",
            resolveReason: .match
        )
        let flagResolution = FlagResolution(
            context: ["hey": ConfidenceValue(string: "old value")],
            flags: [resolvedValue],
            resolveToken: ""
        )

        XCTAssertNoThrow(
            flagResolution.evaluate(
                flagName: "flag_name.string", defaultValue: "default", context: [:])
        )
    }

    func testMissingValueFromCache() throws {
        let resolvedValue = ResolvedValue(
            value: .init(structure: ["string": .init(string: "Value")]),
            flag: "flag_name",
            resolveReason: .match
        )
        let context =
            ["hey": ConfidenceValue(string: "old value")]
        let flagResolution = FlagResolution(context: context, flags: [resolvedValue], resolveToken: "")
        let evaluation = flagResolution.evaluate(flagName: "new_flag_name", defaultValue: "default", context: context)
        XCTAssertEqual(evaluation.value, "default")
        XCTAssertNil(evaluation.variant)
        XCTAssertEqual(evaluation.reason, .error)
        XCTAssertEqual(evaluation.errorCode, .flagNotFound)
        XCTAssertEqual(evaluation.errorMessage, "Flag 'new_flag_name' not found in local cache")
    }
}
