import XCTest
@testable import Confidence

class PayloadMergerTests: XCTestCase {
    func testSimpleMerge() {
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
        let merged = PayloadMergerImpl().merge(context: context, message: message)
        XCTAssertEqual(merged, expected)
    }

    func testOverlapNoStruct() {
        let context = ["a": ConfidenceValue(string: "hello"), "b": ConfidenceValue(string: "world")]
        let message = [
            "b": ConfidenceValue(string: "west"),
            "context": ConfidenceValue(string: "world")  // simple value context is lost
        ]
        let expected = [
            "b": ConfidenceValue(string: "west"),
            "context": ConfidenceValue(structure: [
                "a": ConfidenceValue(string: "hello"),
                "b": ConfidenceValue(string: "world"),
            ])
        ]
        let merged = PayloadMergerImpl().merge(context: context, message: message)
        XCTAssertEqual(merged, expected)
    }

    func testOverlap() {
        let context = ["a": ConfidenceValue(string: "hello"), "b": ConfidenceValue(string: "world")]
        let message = [
            "b": ConfidenceValue(string: "west"),
            "context": ConfidenceValue(structure: [
                "a": ConfidenceValue(double: 2.0),
                "d": ConfidenceValue(string: "inner")
            ])
        ]
        let expected = [
            "b": ConfidenceValue(string: "west"),
            "context": ConfidenceValue(structure: [
                "a": ConfidenceValue(double: 2.0),
                "b": ConfidenceValue(string: "world"),
                "d": ConfidenceValue(string: "inner")
            ])
        ]
        let merged = PayloadMergerImpl().merge(context: context, message: message)
        XCTAssertEqual(merged, expected)
    }
}
