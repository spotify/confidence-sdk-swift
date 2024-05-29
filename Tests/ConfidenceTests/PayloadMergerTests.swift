import XCTest
@testable import Confidence

class PayloadMergerTests: XCTestCase {
    func testMerge() throws {
        let context = ["a": ConfidenceValue(string: "hello"), "b": ConfidenceValue(string: "world")]
        let message = ["b": ConfidenceValue(string: "west"), "c": ConfidenceValue(string: "world")]
        let expected = [
            "b": ConfidenceValue(string: "west"),
            "c": ConfidenceValue(string: "world"),
            "context": ConfidenceValue(structure: [
                "a": ConfidenceValue(string: "hello"),
                "b": ConfidenceValue(string: "world"),
            ])
        ]
        let merged = try PayloadMergerImpl().merge(context: context, data: message)
        XCTAssertEqual(merged, expected)
    }

    func testInvalidMessage() throws {
        let context = ["a": ConfidenceValue(string: "hello"), "b": ConfidenceValue(string: "world")]
        let message = [
            "b": ConfidenceValue(string: "west"),
            "context": ConfidenceValue(string: "world")  // simple value context is lost
        ]
        XCTAssertThrowsError(
            try PayloadMergerImpl().merge(context: context, data: message)
        ) { error in
            XCTAssertEqual(error as? ConfidenceError, ConfidenceError.invalidContextInMessage)
        }
    }
}
