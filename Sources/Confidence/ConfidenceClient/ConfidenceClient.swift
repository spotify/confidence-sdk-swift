import Foundation
import Common

public protocol ConfidenceClient {
    // Returns true if the batch has been correctly processed by the backend
    func upload(batch: [ConfidenceEvent]) async throws -> Bool
}

public struct ConfidenceEvent: Codable {
    var definition: String
    var payload: NetworkStruct
    var eventTime: String
}
