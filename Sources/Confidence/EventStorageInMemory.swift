import Foundation

final class EventStorageInMemory: EventStorage {
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
        // swiftlint:disable:next force_unwrapping
        return batches[id]!
    }

    func remove(id: String) throws {
        batches.removeValue(forKey: id)
    }
}
