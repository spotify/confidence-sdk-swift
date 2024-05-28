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
    // swiftlint:disable implicitly_unwrapped_optional
    var writeQueue: DispatchQueue!
    var uploaderMock: EventUploaderMock!
    var storageMock: EventStorageMock!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUp() async throws {
        writeQueue = DispatchQueue(label: "ConfidenceWriteQueue")
        uploaderMock = EventUploaderMock()
        storageMock = EventStorageMock()
        try await super.setUp()
    }

    func testPayloadOnEmit() throws {
        let eventSenderEngine = EventSenderEngineImpl(
            clientSecret: "CLIENT_SECRET",
            uploader: uploaderMock,
            storage: storageMock,
            flushPolicies: [MinSizeFlushPolicy(maxSize: 1)],
            writeQueue: writeQueue
        )

        let expectation = XCTestExpectation(description: "Upload finished")
        let cancellable = uploaderMock.subject.sink { _ in
            expectation.fulfill()
        }
        eventSenderEngine.emit(
            eventName: "my_event",
            message: [
                "a": .init(integer: 0),
                "context": .init(structure: [
                    "a": .init(string: "test1"),
                    "b": .init(string: "test2"),
                ]),
            ],
            context: [
                "a": .init(integer: 2),
                "d": .init(integer: 3)
            ])


        wait(for: [expectation], timeout: 5)
        XCTAssertEqual(try XCTUnwrap(uploaderMock.calledRequest)[0].eventDefinition, "my_event")
        XCTAssertEqual(try XCTUnwrap(uploaderMock.calledRequest)[0].payload, NetworkStruct(fields: [
            "a": .number(0.0),
            "context": .structure(
                .init(fields: [
                    "a": .string("test1"),
                    "b": .string("test2"),
                    "d": .number(3)
                ])
            )
        ]))
        cancellable.cancel()
    }

    func testAddingEventsWithSizeFlushPolicyWorks() throws {
        let eventSenderEngine = EventSenderEngineImpl(
            clientSecret: "CLIENT_SECRET",
            uploader: uploaderMock,
            storage: storageMock,
            flushPolicies: [MinSizeFlushPolicy(maxSize: 5)],
            writeQueue: writeQueue
        )

        eventSenderEngine.emit(eventName: "Hello", message: [:], context: [:])
        // TODO: We need to wait for writeReqChannel to complete to make this test meaningful
        XCTAssertNil(uploaderMock.calledRequest)
    }

    func testRemoveEventsFromStorageOnBadRequest() throws {
        MockedClientURLProtocol.mockedOperation = .badRequest
        let badRequestUploader = RemoteConfidenceClient(
            options: ConfidenceClientOptions(credentials: ConfidenceClientCredentials.clientSecret(secret: "")),
            session: MockedClientURLProtocol.mockedSession(),
            metadata: ConfidenceMetadata(name: "", version: ""))

        let eventSenderEngine = EventSenderEngineImpl(
            clientSecret: "CLIENT_SECRET",
            uploader: badRequestUploader,
            storage: storageMock,
            flushPolicies: [ImmidiateFlushPolicy()],
            writeQueue: writeQueue
        )
        eventSenderEngine.emit(eventName: "testEvent", message: ConfidenceStruct(), context: ConfidenceStruct())
        let expectation = expectation(description: "events batched")
        storageMock.eventsRemoved{
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)

        XCTAssertEqual(storageMock.isEmpty(), true)
    }

    func testKeepEventsInStorageForRetry() throws {
        MockedClientURLProtocol.mockedOperation = .needRetryLater
        let retryLaterUploader = RemoteConfidenceClient(
            options: ConfidenceClientOptions(credentials: ConfidenceClientCredentials.clientSecret(secret: "")),
            session: MockedClientURLProtocol.mockedSession(),
            metadata: ConfidenceMetadata(name: "", version: ""))

        let eventSenderEngine = EventSenderEngineImpl(
            clientSecret: "CLIENT_SECRET",
            uploader: retryLaterUploader,
            storage: storageMock,
            flushPolicies: [ImmidiateFlushPolicy()],
            writeQueue: writeQueue
        )

        eventSenderEngine.emit(eventName: "testEvent", message: ConfidenceStruct(), context: ConfidenceStruct())

        writeQueue.sync {
            XCTAssertEqual(storageMock.isEmpty(), false)
        }
    }

    func testManualFlushWorks() throws {
        let eventSenderEngine = EventSenderEngineImpl(
            clientSecret: "CLIENT_SECRET",
            uploader: uploaderMock,
            storage: storageMock,
            // no other flush policy is set which means that only manual flushes will trigger upload
            flushPolicies: [],
            writeQueue: writeQueue
        )

        eventSenderEngine.emit(eventName: "Hello", message: [:], context: [:])
        eventSenderEngine.emit(eventName: "Hello", message: [:], context: [:])
        eventSenderEngine.emit(eventName: "Hello", message: [:], context: [:])
        eventSenderEngine.emit(eventName: "Hello", message: [:], context: [:])


        writeQueue.sync {
            XCTAssertEqual(storageMock.events.count, 4)
            XCTAssertNil(uploaderMock.calledRequest)
        }

        eventSenderEngine.flush()

        let uploadExpectation = XCTestExpectation(description: "Upload finished")
        let cancellable = uploaderMock.subject.sink { _ in
            uploadExpectation.fulfill()
        }
        wait(for: [uploadExpectation], timeout: 1)
        let uploadRequest = uploaderMock.calledRequest
        XCTAssertEqual(uploadRequest?.count, 4)

        cancellable.cancel()
    }


    func testManualFlushEventIsNotStored() throws {
        let eventSenderEngine = EventSenderEngineImpl(
            clientSecret: "CLIENT_SECRET",
            uploader: uploaderMock,
            storage: storageMock,
            // no other flush policy is set which means that only manual flushes will trigger upload
            flushPolicies: [],
            writeQueue: writeQueue
        )

        eventSenderEngine.flush()

        XCTAssertEqual(storageMock.events.count, 0)
        XCTAssertNil(uploaderMock.calledRequest)
    }
}
