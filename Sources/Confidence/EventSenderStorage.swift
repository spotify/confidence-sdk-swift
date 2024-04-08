import Foundation

struct EventBatchRequest: Codable {
    let clientSecret: String
    let sendTime: Date
    let events: [Event]
}

internal protocol EventStorage {
    func startNewBatch() throws
    func writeEvent(event: Event) throws
    func batchReadyIds() -> [String]
    func eventsFrom(id: String) throws -> [Event]
    func remove(id: String) throws
}
