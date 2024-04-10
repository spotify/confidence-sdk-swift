import Foundation
import XCTest

@testable import Confidence

final class MinSizeFlushPolicy: FlushPolicy {
    private var maxSize = 5
    private var size = 0
    func reset() {
        size = 0
    }
    
    func hit(event: Event) {
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

        var events: [Event] = []
        for i in 0..<5 {
            events.append(Event(name: "\(i)", payload: [:]))
            eventSenderEngine.send(name: "\(i)", message: [:])
        }

        let expectedRequest = EventBatchRequest(clientSecret: "CLIENT_SECRET", sendTime: Date(), events: events)
        let uploadRequest = try XCTUnwrap(uploader.calledRequest)
        XCTAssertTrue(uploadRequest.clientSecret == expectedRequest.clientSecret)
        XCTAssertTrue(uploadRequest.events == expectedRequest.events)

        uploader.reset()
        eventSenderEngine.send(name: "Hello", message: [:])
        XCTAssertNil(uploader.calledRequest)
    }
}

