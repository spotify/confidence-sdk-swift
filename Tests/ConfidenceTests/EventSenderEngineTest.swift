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

    func testManualFlushWorks() throws {
        let uploaderMock = EventUploaderMock()
        let storageMock = EventStorageMock()
        let eventSenderEngine = EventSenderEngineImpl(
            clientSecret: "CLIENT_SECRET",
            uploader: uploaderMock,
            storage: storageMock,
            // no other flush policy is set which means that only manual flushes will trigger upload
            flushPolicies: []
        )

        eventSenderEngine.emit(eventName: "Hello", message: [:], context: [:])
        eventSenderEngine.emit(eventName: "Hello", message: [:], context: [:])
        eventSenderEngine.emit(eventName: "Hello", message: [:], context: [:])
        eventSenderEngine.emit(eventName: "Hello", message: [:], context: [:])
        XCTAssertEqual(storageMock.events.count, 4)
        XCTAssertNil(uploaderMock.calledRequest)

        eventSenderEngine.flush()

        let expectation = XCTestExpectation(description: "Upload finished")
        let cancellable = uploaderMock.subject.sink { _ in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
        let uploadRequest = uploaderMock.calledRequest
        XCTAssertEqual(uploadRequest?.count, 4)

        cancellable.cancel()
    }


    func testManualFlushEventIsNotStored() throws {
        let uploaderMock = EventUploaderMock()
        let storageMock = EventStorageMock()
        let eventSenderEngine = EventSenderEngineImpl(
            clientSecret: "CLIENT_SECRET",
            uploader: uploaderMock,
            storage: storageMock,
            // no other flush policy is set which means that only manual flushes will trigger upload
            flushPolicies: []
        )

        eventSenderEngine.flush()

        XCTAssertEqual(storageMock.events.count, 0)
        XCTAssertNil(uploaderMock.calledRequest)
    }
}
