import Foundation
import Combine
@testable import Confidence

final class EventUploaderMock: ConfidenceEventsClient {
    var calledRequest: [NetworkEvent]?
    let subject: PassthroughSubject<Int, Never> = PassthroughSubject()

    func upload(events: [NetworkEvent]) async throws -> Bool {
        calledRequest = events
        subject.send(1)
        return true
    }

    func reset() {
        calledRequest = nil
    }
}

final class EventStorageMock: EventStorage {
    var events: [ConfidenceEvent] = []
    var batches: [String: [ConfidenceEvent]] = [:]
    var removeCallback: () -> Void = {}

    func startNewBatch() throws {
        batches[("\(batches.count)")] = events
        events.removeAll()
    }

    func writeEvent(event: ConfidenceEvent) throws {
        events.append(event)
    }

    func batchReadyIds() -> [String] {
        return batches.map { batch in batch.0 }
    }

    func eventsFrom(id: String) throws -> [ConfidenceEvent] {
        guard let events = batches[id] else {
            fatalError("id \(id) not found in batches")
        }
        return events
    }

    func remove(id: String) throws {
        batches.removeValue(forKey: id)
        removeCallback()
    }

    internal func isEmpty() -> Bool {
        return self.events.isEmpty && self.batches.isEmpty
    }

    internal func eventsRemoved(callback: @escaping () -> Void) {
        removeCallback = callback
    }
}
