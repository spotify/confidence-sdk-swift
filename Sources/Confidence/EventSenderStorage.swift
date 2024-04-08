import Foundation

struct EventBatchRequest: Codable {
    let clientSecret: String
    let sendTime: Date
    let events: [Event]
}

protocol EventSenderStorage {
    func createBatch()
    func write(event: Event)
    func batchReadyPaths() -> [String]
    func eventBatchForPath(atPath: String) -> [Event]
    func remove(atPath: String)
}
