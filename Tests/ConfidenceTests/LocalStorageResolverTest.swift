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
            try flagResolution.evaluate(
                flagName: "flag_name.string", defaultValue: "default", context: [:], isProvider: false)
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
        let flagResolution =
            FlagResolution(context: context, flags: [resolvedValue], resolveToken: "")
        XCTAssertThrowsError(
            try flagResolution.evaluate(
                flagName: "new_flag_name",
                defaultValue: "default",
                context: context,
                isProvider: false)
        ) { error in
            XCTAssertEqual(
                error as? ConfidenceError, .flagNotFoundError(key: "new_flag_name"))
        }
    }
}
