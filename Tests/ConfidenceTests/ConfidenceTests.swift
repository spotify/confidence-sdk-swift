import XCTest
@testable import Confidence

final class ConfidenceTests: XCTestCase {
    func testWithContext() {
        let confidenceParent = Confidence.init(
            clientSecret: "",
            timeout: TimeInterval(),
            region: .europe,
            eventSenderEngine: EventSenderEngineMock(),
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
            eventSenderEngine: EventSenderEngineMock(),
            initializationStrategy: .activateAndFetchAsync,
            context: ["k1": ConfidenceValue(string: "v1")],
            parent: nil
        )
        let confidenceChild: ConfidenceEventSender = confidenceParent.withContext(
            ["k2": ConfidenceValue(string: "v2")]
        )
        confidenceParent.putContext(
            key: "k3",
            value: ConfidenceValue(string: "v3"))
        let expected = [
            "k1": ConfidenceValue(string: "v1"),
            "k2": ConfidenceValue(string: "v2"),
            "k3": ConfidenceValue(string: "v3"),
        ]
        XCTAssertEqual(confidenceChild.getContext(), expected)
    }

    func testUpdateLocalContext() {
        let confidence = Confidence.init(
            clientSecret: "",
            timeout: TimeInterval(),
            region: .europe,
            eventSenderEngine: EventSenderEngineMock(),
            initializationStrategy: .activateAndFetchAsync,
            context: ["k1": ConfidenceValue(string: "v1")],
            parent: nil
        )
        confidence.putContext(
            key: "k1",
            value: ConfidenceValue(string: "v3"))
        let expected = [
            "k1": ConfidenceValue(string: "v3"),
        ]
        XCTAssertEqual(confidence.getContext(), expected)
    }

    func testUpdateLocalContextWithoutOverride() {
        let confidenceParent = Confidence.init(
            clientSecret: "",
            timeout: TimeInterval(),
            region: .europe,
            eventSenderEngine: EventSenderEngineMock(),
            initializationStrategy: .activateAndFetchAsync,
            context: ["k1": ConfidenceValue(string: "v1")],
            parent: nil
        )
        let confidenceChild: ConfidenceEventSender = confidenceParent.withContext(
            ["k2": ConfidenceValue(string: "v2")]
        )
        confidenceChild.putContext(
            key: "k2",
            value: ConfidenceValue(string: "v4"))
        let expected = [
            "k1": ConfidenceValue(string: "v1"),
            "k2": ConfidenceValue(string: "v4"),
        ]
        XCTAssertEqual(confidenceChild.getContext(), expected)
    }

    func testUpdateParentContextWithOverride() {
        let confidenceParent = Confidence.init(
            clientSecret: "",
            timeout: TimeInterval(),
            region: .europe,
            eventSenderEngine: EventSenderEngineMock(),
            initializationStrategy: .activateAndFetchAsync,
            context: ["k1": ConfidenceValue(string: "v1")],
            parent: nil
        )
        let confidenceChild: ConfidenceEventSender = confidenceParent.withContext(
            ["k2": ConfidenceValue(string: "v2")]
        )
        confidenceParent.putContext(
            key: "k2",
            value: ConfidenceValue(string: "v4"))
        let expected = [
            "k1": ConfidenceValue(string: "v1"),
            "k2": ConfidenceValue(string: "v2"),
        ]
        XCTAssertEqual(confidenceChild.getContext(), expected)
    }

    func testRemoveContextEntry() {
        let confidence = Confidence.init(
            clientSecret: "",
            timeout: TimeInterval(),
            region: .europe,
            eventSenderEngine: EventSenderEngineMock(),
            initializationStrategy: .activateAndFetchAsync,
            context: [
                "k1": ConfidenceValue(string: "v1"),
                "k2": ConfidenceValue(string: "v2")
            ],
            parent: nil
        )
        confidence.removeContextEntry(key: "k2")
        let expected = [
            "k1": ConfidenceValue(string: "v1")
        ]
        XCTAssertEqual(confidence.getContext(), expected)
    }

    func testRemoveContextEntryFromParent() {
        let confidenceParent = Confidence.init(
            clientSecret: "",
            timeout: TimeInterval(),
            region: .europe,
            eventSenderEngine: EventSenderEngineMock(),
            initializationStrategy: .activateAndFetchAsync,
            context: ["k1": ConfidenceValue(string: "v1")],
            parent: nil
        )
        let confidenceChild: ConfidenceEventSender = confidenceParent.withContext(
            ["k2": ConfidenceValue(string: "v2")]
        )
        confidenceChild.removeContextEntry(key: "k1")
        let expected = [
            "k2": ConfidenceValue(string: "v2")
        ]
        XCTAssertEqual(confidenceChild.getContext(), expected)
    }

    func testRemoveContextEntryFromParentAndChild() {
        let confidenceParent = Confidence.init(
            clientSecret: "",
            timeout: TimeInterval(),
            region: .europe,
            eventSenderEngine: EventSenderEngineMock(),
            initializationStrategy: .activateAndFetchAsync,
            context: ["k1": ConfidenceValue(string: "v1")],
            parent: nil
        )
        let confidenceChild: ConfidenceEventSender = confidenceParent.withContext(
            [
                "k2": ConfidenceValue(string: "v2"),
                "k1": ConfidenceValue(string: "v3"),
            ]
        )
        confidenceChild.removeContextEntry(key: "k1")
        let expected = [
            "k2": ConfidenceValue(string: "v2")
        ]
        XCTAssertEqual(confidenceChild.getContext(), expected)
    }

    func testRemoveContextEntryFromParentAndChildThenUpdate() {
        let confidenceParent = Confidence.init(
            clientSecret: "",
            timeout: TimeInterval(),
            region: .europe,
            eventSenderEngine: EventSenderEngineMock(),
            initializationStrategy: .activateAndFetchAsync,
            context: ["k1": ConfidenceValue(string: "v1")],
            parent: nil
        )
        let confidenceChild: ConfidenceEventSender = confidenceParent.withContext(
            [
                "k2": ConfidenceValue(string: "v2"),
                "k1": ConfidenceValue(string: "v3"),
            ]
        )
        confidenceChild.removeContextEntry(key: "k1")
        confidenceChild.putContext(key: "k1", value: ConfidenceValue(string: "v4"))
        let expected = [
            "k2": ConfidenceValue(string: "v2"),
            "k1": ConfidenceValue(string: "v4"),
        ]
        XCTAssertEqual(confidenceChild.getContext(), expected)
    }
}
