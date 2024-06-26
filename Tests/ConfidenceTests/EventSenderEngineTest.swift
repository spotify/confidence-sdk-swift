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
        let debugLogger = DebugLoggerMock()
        let eventSenderEngine = EventSenderEngineImpl(
            clientSecret: "CLIENT_SECRET",
            uploader: uploaderMock,
            storage: storageMock,
            flushPolicies: [MinSizeFlushPolicy(maxSize: 1)],
            writeQueue: writeQueue,
            debugLogger: debugLogger
        )

        let expectation = XCTestExpectation(description: "Upload finished")
        let cancellable = uploaderMock.subject.sink { _ in
            expectation.fulfill()
        }
        try eventSenderEngine.emit(
            eventName: "my_event",
            data: [
                "a": .init(integer: 0)
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
                    "a": .number(2),
                    "d": .number(3)
                ])
            )
        ]))
        XCTAssertEqual(debugLogger.eventsLogged, 2)
        cancellable.cancel()
    }

    func testAddingEventsWithSizeFlushPolicyWorks() throws {
        let debugLogger = DebugLoggerMock()
        let eventSenderEngine = EventSenderEngineImpl(
            clientSecret: "CLIENT_SECRET",
            uploader: uploaderMock,
            storage: storageMock,
            flushPolicies: [MinSizeFlushPolicy(maxSize: 5)],
            writeQueue: writeQueue,
            debugLogger: debugLogger
        )

        try eventSenderEngine.emit(eventName: "Hello", data: [:], context: [:])
        // TODO: We need to wait for writeReqChannel to complete to make this test meaningful
        XCTAssertNil(uploaderMock.calledRequest)
        XCTAssertEqual(debugLogger.eventsLogged, 1)
    }

    func testRemoveEventsFromStorageOnBadRequest() throws {
        let debugLogger = DebugLoggerMock()
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
            writeQueue: writeQueue,
            debugLogger: debugLogger
        )
        try eventSenderEngine.emit(eventName: "testEvent", data: ConfidenceStruct(), context: ConfidenceStruct())
        let expectation = expectation(description: "events batched")
        storageMock.eventsRemoved{
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)

        XCTAssertEqual(storageMock.isEmpty(), true)
        XCTAssertEqual(debugLogger.eventsLogged, 2)
    }

    func testKeepEventsInStorageForRetry() throws {
        let debugLogger = DebugLoggerMock()
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
            writeQueue: writeQueue,
            debugLogger: debugLogger
        )

        try eventSenderEngine.emit(eventName: "testEvent", data: ConfidenceStruct(), context: ConfidenceStruct())

        writeQueue.sync {
            XCTAssertEqual(storageMock.isEmpty(), false)
        }
        XCTAssertEqual(debugLogger.eventsLogged, 2)
    }

    func testManualFlushWorks() throws {
        let debugLogger = DebugLoggerMock()
        let eventSenderEngine = EventSenderEngineImpl(
            clientSecret: "CLIENT_SECRET",
            uploader: uploaderMock,
            storage: storageMock,
            // no other flush policy is set which means that only manual flushes will trigger upload
            flushPolicies: [],
            writeQueue: writeQueue,
            debugLogger: debugLogger
        )

        try eventSenderEngine.emit(eventName: "Hello", data: [:], context: [:])
        try eventSenderEngine.emit(eventName: "Hello", data: [:], context: [:])
        try eventSenderEngine.emit(eventName: "Hello", data: [:], context: [:])
        try eventSenderEngine.emit(eventName: "Hello", data: [:], context: [:])


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
        XCTAssertEqual(debugLogger.eventsLogged, 9)

        cancellable.cancel()
    }


    func testManualFlushEventIsNotStored() throws {
        let debugLogger = DebugLoggerMock()
        let eventSenderEngine = EventSenderEngineImpl(
            clientSecret: "CLIENT_SECRET",
            uploader: uploaderMock,
            storage: storageMock,
            // no other flush policy is set which means that only manual flushes will trigger upload
            flushPolicies: [],
            writeQueue: writeQueue,
            debugLogger: debugLogger
        )

        eventSenderEngine.flush()

        XCTAssertEqual(storageMock.events.count, 0)
        XCTAssertNil(uploaderMock.calledRequest)
        XCTAssertEqual(debugLogger.eventsLogged, 1)
    }
}
