import Foundation
import XCTest

@testable import Confidence

class EventStorageTest: XCTestCase {

    func testCreateNewBatch() throws {
        let eventStorage = try! EventStorageImpl()
        eventStorage.writeEvent(event: Event(eventDefinition: "some event", eventTime: Date().self, payload: ["pants"], context: ["pants context"]))
        eventStorage.startNewBatch()
        print("✅",eventStorage.batchReadyIds())
        //timestamp isnt in the filename
        XCTAssertEqual(eventStorage.batchReadyIds().count, 1)
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
