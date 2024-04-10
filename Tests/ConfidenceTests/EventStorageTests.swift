import Foundation
import XCTest

@testable import Confidence

class EventStorageTest: XCTestCase {

    func testCreateNewBatch() throws {
        let eventStorage = try EventStorageImpl()
        try eventStorage.writeEvent(event: Event(eventDefinition: "some event", eventTime: Date().self, payload: ["pants"], context: ["pants context"]))
        try eventStorage.startNewBatch()
        try XCTAssertEqual(eventStorage.batchReadyIds().count, 1)
        let events = try eventStorage.eventsFrom(id: try eventStorage.batchReadyIds()[0])
        try XCTAssertEqual(events[0].eventDefinition, "some event")
    }

    func testContinueWritingToOldBatch() {

    }

    func testRolloverToNewBatchWhenBatchIsFull() {

    }

    func testGetReadyFilesToSend() {

    }

    func testGetEventsFromFile() {
        
    }

    func testRemoveFile() {
        
    }
}


//struct Event: Codable {
//    let eventDefinition: String
//    let eventTime: Date
//    // TODO: fix this to be ConfidenceValue
//    let payload: [String]
//    let context: [String]
//}
