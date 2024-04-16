import Foundation
import Combine
@testable import Confidence

final class EventUploaderMock: ConfidenceClient {
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
    private var events: [ConfidenceEvent] = []
    private var batches: [String: [ConfidenceEvent]] = [:]
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
    }
}
