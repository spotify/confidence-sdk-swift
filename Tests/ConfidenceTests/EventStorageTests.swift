import Foundation
import XCTest

@testable import Confidence

class EventStorageTest: XCTestCase {
    override func setUp() async throws {
        let folderURL = try! EventStorageImpl.getFolderURL()
        if FileManager.default.fileExists(atPath: folderURL.path) {
            try! FileManager.default.removeItem(at: folderURL)
        }
    }

    func testCreateNewBatch() throws {
        let eventStorage = try EventStorageImpl()
        try eventStorage.writeEvent(event: Event(eventDefinition: "some event", eventTime: Date().self, payload: ["pants"], context: ["pants context"]))
        try eventStorage.writeEvent(event: Event(eventDefinition: "some event 2", eventTime: Date().self, payload: ["pants"], context: ["pants context"]))
        try eventStorage.startNewBatch()
        try XCTAssertEqual(eventStorage.batchReadyIds().count, 1)
        let events = try eventStorage.eventsFrom(id: try eventStorage.batchReadyIds()[0])
        XCTAssertEqual(events[0].eventDefinition, "some event")
        XCTAssertEqual(events[1].eventDefinition, "some event 2")
    }

    func testContinueWritingToOldBatch() throws {
        let eventStorage = try EventStorageImpl()
        try eventStorage.writeEvent(event: Event(eventDefinition: "some event", eventTime: Date().self, payload: ["pants"], context: ["pants context"]))
        // user stops using app, new session after this
        let eventStorageNew = try EventStorageImpl()
        try eventStorageNew.writeEvent(event: Event(eventDefinition: "some event 2", eventTime: Date().self, payload: ["pants"], context: ["pants context"]))
        try eventStorageNew.startNewBatch()
        try XCTAssertEqual(eventStorageNew.batchReadyIds().count, 1)
        let events = try eventStorageNew.eventsFrom(id: try eventStorageNew.batchReadyIds()[0])
        XCTAssertEqual(events[0].eventDefinition, "some event")
        XCTAssertEqual(events[1].eventDefinition, "some event 2")
    }

    func testRemoveFile() throws {
        let eventStorage = try EventStorageImpl()
        try eventStorage.writeEvent(event: Event(eventDefinition: "some event", eventTime: Date().self, payload: ["pants"], context: ["pants context"]))
        try eventStorage.writeEvent(event: Event(eventDefinition: "some event 2", eventTime: Date().self, payload: ["pants"], context: ["pants context"]))
        try eventStorage.startNewBatch()
        try eventStorage.remove(id: eventStorage.batchReadyIds()[0])
        try XCTAssertEqual(eventStorage.batchReadyIds().count, 0)
    }
}
