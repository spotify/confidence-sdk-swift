import Foundation
import Combine
@testable import Confidence

final class EventUploaderMock: ConfidenceClient {
    var calledRequest: [ConfidenceEvent]? = nil
    let subject: PassthroughSubject<Int, Never> = PassthroughSubject()

    func upload(batch: [ConfidenceEvent]) async throws -> Bool {
        calledRequest = batch
        subject.send(1)
        return true
    }

    func reset() {
        calledRequest = nil
    }
}

final class ClockMock: Clock {
    func now() -> Date {
        return Date()
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
        return batches.map({ batch in batch.0})
    }
    
    func eventsFrom(id: String) throws -> [ConfidenceEvent] {
        return batches[id]!
    }
    
    func remove(id: String) throws {
        batches.removeValue(forKey: id)
    }

}
