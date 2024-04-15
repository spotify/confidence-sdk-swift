import Foundation
import Common

protocol ConfidenceClient {
    // Returns true if the batch has been correctly processed by the backend
    func upload(batch: [ConfidenceEvent]) async throws -> Bool
}

struct ConfidenceEvent: Codable {
    var name: String
    var payload: NetworkStruct
    var time: String
}
