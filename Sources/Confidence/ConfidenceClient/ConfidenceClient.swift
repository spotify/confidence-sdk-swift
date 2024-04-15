import Foundation
import Common

protocol ConfidenceClient {
    // Returns true if the batch has been correctly processed by the backend
    func upload(events: [NetworkEvent]) async throws -> Bool
}
