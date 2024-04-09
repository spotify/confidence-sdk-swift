import Confidence
import XCTest

final class ConfidenceTests: XCTestCase {
    func testWithContext() {
        let confidenceParent = Confidence.init(
            clientSecret: "",
            timeout: TimeInterval(),
            region: .europe,
            initializationStrategy: .activateAndFetchAsync,
            context: ["k1": ConfidenceValue(string: "v1")]
        )
        let confidenceChild: ConfidenceEventSender = confidenceParent.withContext(
            ["k2": ConfidenceValue(string: "v2")]
        )
        let expected = [
            "k1": ConfidenceValue(string: "v1"),
            "k2": ConfidenceValue(string: "v2")
        ]
        XCTAssertEqual(confidenceChild.getContext(), expected)
    }

    func testWithContextUpdateParent() {
        let confidenceParent = Confidence.init(
            clientSecret: "",
            timeout: TimeInterval(),
            region: .europe,
            initializationStrategy: .activateAndFetchAsync,
            context: ["k1": ConfidenceValue(string: "v1")]
        )
        let confidenceChild: ConfidenceEventSender = confidenceParent.withContext(
            ["k2": ConfidenceValue(string: "v2")]
        )
        confidenceParent.updateContextEntry(
            key: "k3",
            value: ConfidenceValue(string: "v3"))
        let expected = [
            "k1": ConfidenceValue(string: "v1"),
            "k2": ConfidenceValue(string: "v2"),
            "k3": ConfidenceValue(string: "v3"),
        ]
        XCTAssertEqual(confidenceChild.getContext(), expected)
    }

    func testUpdateContextWithOverride() {
        let confidence = Confidence.init(
            clientSecret: "",
            timeout: TimeInterval(),
            region: .europe,
            initializationStrategy: .activateAndFetchAsync,
            context: ["k1": ConfidenceValue(string: "v1")]
        )
        confidence.updateContextEntry(
            key: "k1",
            value: ConfidenceValue(string: "v3"))
        let expected = [
            "k1": ConfidenceValue(string: "v3"),
        ]
        XCTAssertEqual(confidence.getContext(), expected)
    }

    func testWithContextUpdateParentWithoutOverride() {
        let confidenceParent = Confidence.init(
            clientSecret: "",
            timeout: TimeInterval(),
            region: .europe,
            initializationStrategy: .activateAndFetchAsync,
            context: ["k1": ConfidenceValue(string: "v1")]
        )
        let confidenceChild: ConfidenceEventSender = confidenceParent.withContext(
            ["k2": ConfidenceValue(string: "v2")]
        )
        confidenceParent.updateContextEntry(
            key: "k2",
            value: ConfidenceValue(string: "v4"))
        let expected = [
            "k1": ConfidenceValue(string: "v1"),
            "k2": ConfidenceValue(string: "v2"),
        ]
        XCTAssertEqual(confidenceChild.getContext(), expected)
    }

    func testWithContextUpdateChildWithOverride() {
        let confidenceParent = Confidence.init(
            clientSecret: "",
            timeout: TimeInterval(),
            region: .europe,
            initializationStrategy: .activateAndFetchAsync,
            context: ["k1": ConfidenceValue(string: "v1")]
        )
        let confidenceChild: ConfidenceEventSender = confidenceParent.withContext(
            ["k2": ConfidenceValue(string: "v2")]
        )
        confidenceChild.updateContextEntry(
            key: "k2",
            value: ConfidenceValue(string: "v4"))
        let expected = [
            "k1": ConfidenceValue(string: "v1"),
            "k2": ConfidenceValue(string: "v4"),
        ]
        XCTAssertEqual(confidenceChild.getContext(), expected)
    }

    func testRemoveContextEntry() {
        let confidence = Confidence.init(
            clientSecret: "",
            timeout: TimeInterval(),
            region: .europe,
            initializationStrategy: .activateAndFetchAsync,
            context: [
                "k1": ConfidenceValue(string: "v1"),
                "k2": ConfidenceValue(string: "v2")
            ]
        )
        confidence.removeContextEntry(key: "k2")
        let expected = [
            "k1": ConfidenceValue(string: "v1")
        ]
        XCTAssertEqual(confidence.getContext(), expected)
    }

    func testClearContext() {
        let confidence = Confidence.init(
            clientSecret: "",
            timeout: TimeInterval(),
            region: .europe,
            initializationStrategy: .activateAndFetchAsync,
            context: [
                "k1": ConfidenceValue(string: "v1"),
                "k2": ConfidenceValue(string: "v2")
            ]
        )
        confidence.clearContext()
        let expected: ConfidenceStruct = [:]
        XCTAssertEqual(confidence.getContext(), expected)
    }
}
