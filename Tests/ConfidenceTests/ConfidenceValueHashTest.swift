import XCTest

@testable import Confidence

final class ContextHashEqualityTests: XCTestCase {
    func testHashRespectsTargetingKey() throws {
        let ctx1: ConfidenceStruct =
        ["targetingKey": ConfidenceValue(string: "user1"), "structure": ConfidenceValue(structure: [:])]
        let ctx2: ConfidenceStruct =
        ["targetingKey": ConfidenceValue(string: "user2"), "structure": ConfidenceValue(structure: [:])]

        XCTAssertNotEqual(ctx1.hash(), ctx2.hash())
    }

    func testHashRespectsStructure() throws {
        let ctx1: ConfidenceStruct =
        [
            "targetingKey": ConfidenceValue(string: "user1"),
            "structure": ConfidenceValue(structure: ["integer": ConfidenceValue(integer: 3)])
        ]
        let ctx2: ConfidenceStruct =
        [
            "targetingKey": ConfidenceValue(string: "user2"),
            "structure": ConfidenceValue(structure: ["integer": ConfidenceValue(integer: 4)])
        ]

        XCTAssertNotEqual(ctx1.hash(), ctx2.hash())
    }

    func testHashIsEqualForEqualContext() throws {
        let ctx1: ConfidenceStruct =
        [
            "targetingKey": ConfidenceValue(string: "user1"),
            "structure": ConfidenceValue(structure: ["integer": ConfidenceValue(integer: 3)])
        ]
        let ctx2: ConfidenceStruct =
        [
            "targetingKey": ConfidenceValue(string: "user1"),
            "structure": ConfidenceValue(structure: ["integer": ConfidenceValue(integer: 3)])
        ]

        XCTAssertEqual(ctx1.hash(), ctx2.hash())
    }
}
