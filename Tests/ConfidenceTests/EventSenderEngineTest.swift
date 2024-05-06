import Foundation
import XCTest

@testable import Confidence

final class MinSizeFlushPolicy: FlushPolicy {
    private var maxSize: Int
    private var size = 0

    init(maxSize: Int) {
        self.maxSize = maxSize
    }
    func reset() {
        size = 0
    }

    func hit(event: ConfidenceEvent) {
        size += 1
    }

    func shouldFlush() -> Bool {
        return size >= maxSize
    }
}

final class ImmidiateFlushPolicy: FlushPolicy {
    private var size = 0

    func reset() {
        size = 0
    }

    func hit(event: ConfidenceEvent) {
        size += 1
    }

    func shouldFlush() -> Bool {
        return size > 0
    }
}

final class EventSenderEngineTest: XCTestCase {
    func testPayloadOnEmit() throws {
        let flushPolicies = [MinSizeFlushPolicy(maxSize: 1)]
        let uploader = EventUploaderMock()
        let eventSenderEngine = EventSenderEngineImpl(
            clientSecret: "CLIENT_SECRET",
            uploader: uploader,
            storage: EventStorageMock(),
            flushPolicies: flushPolicies
        )

        let expectation = XCTestExpectation(description: "Upload finished")
        let cancellable = uploader.subject.sink { _ in
            expectation.fulfill()
        }
        eventSenderEngine.emit(
            eventName: "my_event",
            message: [
                "a": .init(integer: 0),
                "message": .init(integer: 1),
            ],
            context: [
                "a": .init(integer: 2),
                "message": .init(integer: 3) // the root "message" overrides this
            ])


        wait(for: [expectation], timeout: 5)
        XCTAssertEqual(try XCTUnwrap(uploader.calledRequest)[0].eventDefinition, "my_event")
        XCTAssertEqual(try XCTUnwrap(uploader.calledRequest)[0].payload, NetworkStruct(fields: [
            "a": .number(0.0),
            "message": .number(1.0)
        ]))
        cancellable.cancel()
    }

    func testAddingEventsWithSizeFlushPolicyWorks() throws {
        let flushPolicies = [MinSizeFlushPolicy(maxSize: 5)]
        let uploader = EventUploaderMock()
        let eventSenderEngine = EventSenderEngineImpl(
            clientSecret: "CLIENT_SECRET",
            uploader: uploader,
            storage: EventStorageMock(),
            flushPolicies: flushPolicies
        )

        eventSenderEngine.emit(eventName: "Hello", message: [:], context: [:])
        // TODO: We need to wait for writeReqChannel to complete to make this test meaningful
        XCTAssertNil(uploader.calledRequest)
    }

    func testRemoveEventsFromStorageOnBadRequest() throws {
        MockedClientURLProtocol.mockedOperation = .badRequest
        let client = RemoteConfidenceClient(
            options: ConfidenceClientOptions(credentials: ConfidenceClientCredentials.clientSecret(secret: "")),
            session: MockedClientURLProtocol.mockedSession(),
            metadata: ConfidenceMetadata(name: "", version: ""))

        let flushPolicies = [ImmidiateFlushPolicy()]
        let storage = EventStorageMock()
        let eventSenderEngine = EventSenderEngineImpl(
            clientSecret: "CLIENT_SECRET",
            uploader: client,
            storage: storage,
            flushPolicies: flushPolicies
        )
        eventSenderEngine.emit(eventName: "testEvent", message: ConfidenceStruct(), context: ConfidenceStruct())
        let expectation = expectation(description: "events batched")
        storage.eventsRemoved{
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)

        XCTAssertEqual(storage.isEmpty(), true)
    }

    func testKeepEventsInStorageForRetry() throws {
        MockedClientURLProtocol.mockedOperation = .needRetryLater
        let client = RemoteConfidenceClient(
            options: ConfidenceClientOptions(credentials: ConfidenceClientCredentials.clientSecret(secret: "")),
            session: MockedClientURLProtocol.mockedSession(),
            metadata: ConfidenceMetadata(name: "", version: ""))

        let flushPolicies = [ImmidiateFlushPolicy()]
        let storage = EventStorageMock()
        let eventSenderEngine = EventSenderEngineImpl(
            clientSecret: "CLIENT_SECRET",
            uploader: client,
            storage: storage,
            flushPolicies: flushPolicies
        )

        eventSenderEngine.emit(eventName: "testEvent", message: ConfidenceStruct(), context: ConfidenceStruct())

        XCTAssertEqual(storage.isEmpty(), false)
    }
}
