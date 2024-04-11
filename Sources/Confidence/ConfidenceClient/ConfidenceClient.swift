import Foundation
import Common

public protocol ConfidenceClient {
    func upload(batch: [ConfidenceClientEvent]) async throws
}

public struct ConfidenceClientEvent {
    var definition: String
    var payload: NetworkStruct
}
