import Foundation

struct EventBatchRequest: Codable {
    let clientSecret: String
    let sendTime: Date
    let events: [Event]
}

internal protocol EventStorage {
    func startNewBatch() throws
    func writeEvent(event: Event) throws
    func batchReadyFiles() -> [URL]
    func eventsFrom(fileURL: URL) throws -> [Event]
    func remove(fileUrl: URL) throws
}
