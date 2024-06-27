import XCTest
@testable import Confidence

// swiftlint:disable type_body_length
final class ConfidenceContextTests: XCTestCase {
    func testWithContext() {
        let client = RemoteConfidenceResolveClient(
            options: ConfidenceClientOptions(
                credentials: ConfidenceClientCredentials.clientSecret(secret: "")),
            session: MockedClientURLProtocol.mockedSession(),
            metadata: ConfidenceMetadata(name: "", version: ""))

        let confidenceParent = Confidence.init(
            clientSecret: "",
            region: .europe,
            eventSenderEngine: EventSenderEngineMock(),
            flagApplier: FlagApplierMock(),
            remoteFlagResolver: client,
            storage: StorageMock(),
            context: ["k1": ConfidenceValue(string: "v1")],
            debugLogger: nil
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
        let client = RemoteConfidenceResolveClient(
            options: ConfidenceClientOptions(
                credentials: ConfidenceClientCredentials.clientSecret(secret: "")),
            session: MockedClientURLProtocol.mockedSession(),
            metadata: ConfidenceMetadata(name: "", version: ""))

        let confidenceParent = Confidence.init(
            clientSecret: "",
            region: .europe,
            eventSenderEngine: EventSenderEngineMock(),
            flagApplier: FlagApplierMock(),
            remoteFlagResolver: client,
            storage: StorageMock(),
            context: ["k1": ConfidenceValue(string: "v1")],
            parent: nil,
            debugLogger: nil
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
        let client = RemoteConfidenceResolveClient(
            options: ConfidenceClientOptions(
                credentials: ConfidenceClientCredentials.clientSecret(secret: "")),
            session: MockedClientURLProtocol.mockedSession(),
            metadata: ConfidenceMetadata(name: "", version: ""))

        let confidence = Confidence.init(
            clientSecret: "",
            region: .europe,
            eventSenderEngine: EventSenderEngineMock(),
            flagApplier: FlagApplierMock(),
            remoteFlagResolver: client,
            storage: StorageMock(),
            context: ["k1": ConfidenceValue(string: "v1")],
            parent: nil,
            debugLogger: nil
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
        let client = RemoteConfidenceResolveClient(
            options: ConfidenceClientOptions(
                credentials: ConfidenceClientCredentials.clientSecret(secret: "")),
            session: MockedClientURLProtocol.mockedSession(),
            metadata: ConfidenceMetadata(name: "", version: ""))

        let confidenceParent = Confidence.init(
            clientSecret: "",
            region: .europe,
            eventSenderEngine: EventSenderEngineMock(),
            flagApplier: FlagApplierMock(),
            remoteFlagResolver: client,
            storage: StorageMock(),
            context: ["k1": ConfidenceValue(string: "v1")],
            parent: nil,
            debugLogger: nil
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
        let client = RemoteConfidenceResolveClient(
            options: ConfidenceClientOptions(
                credentials: ConfidenceClientCredentials.clientSecret(secret: "")),
            session: MockedClientURLProtocol.mockedSession(),
            metadata: ConfidenceMetadata(name: "", version: ""))

        let confidenceParent = Confidence.init(
            clientSecret: "",
            region: .europe,
            eventSenderEngine: EventSenderEngineMock(),
            flagApplier: FlagApplierMock(),
            remoteFlagResolver: client,
            storage: StorageMock(),
            context: ["k1": ConfidenceValue(string: "v1")],
            parent: nil,
            debugLogger: nil
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
        let client = RemoteConfidenceResolveClient(
            options: ConfidenceClientOptions(
                credentials: ConfidenceClientCredentials.clientSecret(secret: "")),
            session: MockedClientURLProtocol.mockedSession(),
            metadata: ConfidenceMetadata(name: "", version: ""))

        let confidence = Confidence.init(
            clientSecret: "",
            region: .europe,
            eventSenderEngine: EventSenderEngineMock(),
            flagApplier: FlagApplierMock(),
            remoteFlagResolver: client,
            storage: StorageMock(),
            context: ["k1": ConfidenceValue(string: "v1")],
            parent: nil,
            debugLogger: nil
        )
        confidence.removeKey(key: "k2")
        let expected = [
            "k1": ConfidenceValue(string: "v1")
        ]
        XCTAssertEqual(confidence.getContext(), expected)
    }

    func testRemoveContextEntryFromParent() {
        let client = RemoteConfidenceResolveClient(
            options: ConfidenceClientOptions(
                credentials: ConfidenceClientCredentials.clientSecret(secret: "")),
            session: MockedClientURLProtocol.mockedSession(),
            metadata: ConfidenceMetadata(name: "", version: ""))

        let confidenceParent = Confidence.init(
            clientSecret: "",
            region: .europe,
            eventSenderEngine: EventSenderEngineMock(),
            flagApplier: FlagApplierMock(),
            remoteFlagResolver: client,
            storage: StorageMock(),
            context: ["k1": ConfidenceValue(string: "v1")],
            parent: nil,
            debugLogger: nil
        )
        let confidenceChild: ConfidenceEventSender = confidenceParent.withContext(
            ["k2": ConfidenceValue(string: "v2")]
        )
        confidenceChild.removeKey(key: "k1")
        let expected = [
            "k2": ConfidenceValue(string: "v2")
        ]
        XCTAssertEqual(confidenceChild.getContext(), expected)
    }

    func testRemoveContextEntryFromParentAndChild() {
        let client = RemoteConfidenceResolveClient(
            options: ConfidenceClientOptions(
                credentials: ConfidenceClientCredentials.clientSecret(secret: "")),
            session: MockedClientURLProtocol.mockedSession(),
            metadata: ConfidenceMetadata(name: "", version: ""))

        let confidenceParent = Confidence.init(
            clientSecret: "",
            region: .europe,
            eventSenderEngine: EventSenderEngineMock(),
            flagApplier: FlagApplierMock(),
            remoteFlagResolver: client,
            storage: StorageMock(),
            context: ["k1": ConfidenceValue(string: "v1")],
            parent: nil,
            debugLogger: nil
        )
        let confidenceChild: ConfidenceEventSender = confidenceParent.withContext(
            [
                "k2": ConfidenceValue(string: "v2"),
                "k1": ConfidenceValue(string: "v3"),
            ]
        )
        confidenceChild.removeKey(key: "k1")
        let expected = [
            "k2": ConfidenceValue(string: "v2")
        ]
        XCTAssertEqual(confidenceChild.getContext(), expected)
    }

    func testRemoveContextEntryFromParentAndChildThenUpdate() {
        let client = RemoteConfidenceResolveClient(
            options: ConfidenceClientOptions(
                credentials: ConfidenceClientCredentials.clientSecret(secret: "")),
            session: MockedClientURLProtocol.mockedSession(),
            metadata: ConfidenceMetadata(name: "", version: ""))

        let confidenceParent = Confidence.init(
            clientSecret: "",
            region: .europe,
            eventSenderEngine: EventSenderEngineMock(),
            flagApplier: FlagApplierMock(),
            remoteFlagResolver: client,
            storage: StorageMock(),
            context: ["k1": ConfidenceValue(string: "v1")],
            parent: nil,
            debugLogger: nil
        )
        let confidenceChild: ConfidenceEventSender = confidenceParent.withContext(
            [
                "k2": ConfidenceValue(string: "v2"),
                "k1": ConfidenceValue(string: "v3"),
            ]
        )
        confidenceChild.removeKey(key: "k1")
        confidenceChild.putContext(key: "k1", value: ConfidenceValue(string: "v4"))
        let expected = [
            "k2": ConfidenceValue(string: "v2"),
            "k1": ConfidenceValue(string: "v4"),
        ]
        XCTAssertEqual(confidenceChild.getContext(), expected)
    }

    func testVisitorId() {
        let client = RemoteConfidenceResolveClient(
            options: ConfidenceClientOptions(
                credentials: ConfidenceClientCredentials.clientSecret(secret: "")),
            session: MockedClientURLProtocol.mockedSession(),
            metadata: ConfidenceMetadata(name: "", version: ""))

        let confidence = Confidence.init(
            clientSecret: "",
            region: .europe,
            eventSenderEngine: EventSenderEngineMock(),
            flagApplier: FlagApplierMock(),
            remoteFlagResolver: client,
            storage: StorageMock(),
            context: ["k1": ConfidenceValue(string: "v1")],
            parent: nil,
            visitorId: "uuid",
            debugLogger: nil
        )
        let expected = [
            "k1": ConfidenceValue(string: "v1"),
            "visitor_id": ConfidenceValue(string: "uuid")
        ]
        XCTAssertEqual(confidence.getContext(), expected)
    }

    func testWithVisitorId() throws {
        let userDefaults = UserDefaults.standard
        userDefaults.removeObject(forKey: "confidence.visitor_id")
        let confidence = Confidence.Builder(clientSecret: "")
            .build()
        let visitorId = try XCTUnwrap(confidence.getContext()["visitor_id"]?.asString())
        XCTAssertNotEqual(visitorId, "")
        XCTAssertNotEqual(visitorId, "storage-error")
        let newConfidence = Confidence.Builder(clientSecret: "")
            .build()
        XCTAssertEqual(visitorId, try XCTUnwrap(newConfidence.getContext()["visitor_id"]?.asString()))
        userDefaults.removeObject(forKey: "confidence.visitor_id")
        let veryNewConfidence = Confidence.Builder(clientSecret: "")
            .build()
        let newVisitorId = try XCTUnwrap(veryNewConfidence.getContext()["visitor_id"]?.asString())
        XCTAssertNotEqual(newVisitorId, "")
        XCTAssertNotEqual(newVisitorId, "storage-error")
        XCTAssertNotEqual(newVisitorId, visitorId)
    }
}
// swiftlint:enable type_body_length
