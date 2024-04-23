import Foundation
import Common
import XCTest

@testable import Confidence

final class MinSizeFlushPolicy: FlushPolicy {
    private var maxSize = 5
    private var size = 0
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
    func testAddingEventsWithSizeFlushPolicyWorks() throws {
        let flushPolicies = [MinSizeFlushPolicy()]
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

        var events: [ConfidenceEvent] = []
        for i in 0..<5 {
            events.append(ConfidenceEvent(
                name: "\(i)",
                payload: [:],
                eventTime: Date.backport.now)
            )
            eventSenderEngine.emit(eventName: "\(i)", message: [:], context: [:])
        }

        wait(for: [expectation], timeout: 5)
        let uploadRequest = try XCTUnwrap(uploader.calledRequest)
        XCTAssertTrue(uploadRequest.map { $0.eventDefinition } == events.map { $0.name })

        uploader.reset()
        eventSenderEngine.emit(eventName: "Hello", message: [:], context: [:])
        XCTAssertNil(uploader.calledRequest)
        cancellable.cancel()
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
