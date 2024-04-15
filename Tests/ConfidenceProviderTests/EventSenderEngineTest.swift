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

final class EventSenderEngineTest: XCTestCase {
    func testAddingEventsWithSizeFlushPolicyWorks() throws {
        let flushPolicies = [MinSizeFlushPolicy()]
        let uploader = EventUploaderMock()
        let eventSenderEngine = EventSenderEngineImpl(
            clientSecret: "CLIENT_SECRET",
            uploader: uploader,
            clock: ClockMock(),
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
                payload: NetworkStruct.init(fields: [:]),
                time: Date.backport.nowISOString)
            )
            try eventSenderEngine.send(name: "\(i)", message: ConfidenceStruct())
        }

        wait(for: [expectation], timeout: 5)
        let uploadRequest = try XCTUnwrap(uploader.calledRequest)
        XCTAssertTrue(uploadRequest.map { $0.name } == events.map { $0.name })

        uploader.reset()
        try eventSenderEngine.send(name: "Hello", message: [:])
        XCTAssertNil(uploader.calledRequest)
        cancellable.cancel()
    }
}
