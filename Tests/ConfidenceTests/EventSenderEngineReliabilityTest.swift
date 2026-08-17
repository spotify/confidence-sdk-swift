import Foundation
import XCTest

@testable import Confidence

final class EventSenderEngineReliabilityTest: XCTestCase {
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

    func testStartupUploadsPendingReadyBatchesWithoutSealingCurrentBatch() throws {
        storageMock.events = [
            ConfidenceEvent(name: "pending", payload: [:], eventTime: Date.backport.now)
        ]
        try storageMock.startNewBatch()
        storageMock.events = [
            ConfidenceEvent(name: "current", payload: [:], eventTime: Date.backport.now)
        ]

        let expectation = XCTestExpectation(description: "Startup upload finished")
        let cancellable = uploaderMock.subject.sink { _ in
            expectation.fulfill()
        }

        _ = EventSenderEngineImpl(
            clientSecret: "CLIENT_SECRET",
            uploader: uploaderMock,
            storage: storageMock,
            flushPolicies: [],
            writeQueue: writeQueue,
            debugLogger: nil
        )

        wait(for: [expectation], timeout: 5)
        XCTAssertEqual(uploaderMock.calledRequest?.count, 1)
        XCTAssertEqual(uploaderMock.calledRequest?.first?.eventDefinition, "pending")
        XCTAssertEqual(storageMock.events.count, 1)
        XCTAssertEqual(storageMock.events.first?.name, "current")
        cancellable.cancel()
    }

    func testShutdownUploadsCurrentBatch() throws {
        let eventSenderEngine = EventSenderEngineImpl(
            clientSecret: "CLIENT_SECRET",
            uploader: uploaderMock,
            storage: storageMock,
            flushPolicies: [],
            writeQueue: writeQueue,
            debugLogger: nil
        )

        let uploadExpectation = XCTestExpectation(description: "Shutdown upload finished")
        let cancellable = uploaderMock.subject.sink { _ in
            uploadExpectation.fulfill()
        }

        try eventSenderEngine.emit(eventName: "session-end", data: [:], context: [:])

        eventSenderEngine.shutdown()

        wait(for: [uploadExpectation], timeout: 5)
        XCTAssertEqual(uploaderMock.calledRequest?.count, 1)
        XCTAssertEqual(uploaderMock.calledRequest?.first?.eventDefinition, "session-end")
        cancellable.cancel()
    }

    func testPeriodicFlushIntervalUploadsEvents() throws {
        let eventSenderEngine = EventSenderEngineImpl(
            clientSecret: "CLIENT_SECRET",
            uploader: uploaderMock,
            storage: storageMock,
            flushPolicies: [],
            writeQueue: writeQueue,
            debugLogger: nil,
            flushInterval: 0.1
        )

        let uploadExpectation = XCTestExpectation(description: "Interval upload finished")
        let cancellable = uploaderMock.subject.sink { _ in
            uploadExpectation.fulfill()
        }

        try eventSenderEngine.emit(eventName: "interval-event", data: [:], context: [:])
        writeQueue.sync { }

        wait(for: [uploadExpectation], timeout: 5)
        XCTAssertEqual(uploaderMock.calledRequest?.first?.eventDefinition, "interval-event")
        eventSenderEngine.shutdown()
        cancellable.cancel()
    }

    func testEmitAfterShutdownIsDropped() throws {
        let eventSenderEngine = EventSenderEngineImpl(
            clientSecret: "CLIENT_SECRET",
            uploader: uploaderMock,
            storage: storageMock,
            flushPolicies: [],
            writeQueue: writeQueue,
            debugLogger: nil
        )

        eventSenderEngine.shutdown()

        try eventSenderEngine.emit(eventName: "after-shutdown", data: [:], context: [:])
        writeQueue.sync { }

        XCTAssertTrue(storageMock.events.isEmpty)
    }
}
