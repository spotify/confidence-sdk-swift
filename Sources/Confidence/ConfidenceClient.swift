import Foundation

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
    var resolveReason: ResolveReason
}

public struct ResolvesResult: Codable, Equatable {
    var resolvedValues: [ResolvedValue]
    var resolveToken: String?
}
