import XCTest
@testable import Confidence

class PayloadMergerTests: XCTestCase {
    func testMerge() {
        let context = ["a": ConfidenceValue(string: "hello"), "b": ConfidenceValue(string: "world")]
        let message = ["b": ConfidenceValue(string: "west"), "c": ConfidenceValue(string: "world")]
        let expected = [
            "a": ConfidenceValue(string: "hello"),
            "b": ConfidenceValue(string: "west"),
            "c": ConfidenceValue(string: "world")
        ]
        let merged = PayloadMergerImpl().merge(context: context, message: message)
        XCTAssertEqual(merged, expected)
    }
}
