import Foundation
import Common

protocol ConfidenceClient {
    // Returns true if the batch has been correctly processed by the backend
    func upload(events: [NetworkEvent]) async throws -> Bool
}

protocol ConfidenceResolveClient {
    // Async
    func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult
}

struct ResolvedValue: Codable, Equatable {
    var variant: String?
    var value: ConfidenceValue?
    var flag: String
    var resolveReason: Reason

    enum Reason: Int, Codable, Equatable {
        case match = 0
        case noMatch = 1
        case targetingKeyError = 2
        case generalError = 3
        case disabled = 4
        case stale = 5
    }
}

public struct ResolvesResult: Codable, Equatable {
    var resolvedValues: [ResolvedValue]
    var resolveToken: String?
}
