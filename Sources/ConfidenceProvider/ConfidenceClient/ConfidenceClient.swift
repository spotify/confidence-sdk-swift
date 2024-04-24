import Foundation
import Confidence
import OpenFeature

public protocol ConfidenceResolveClient {
    // Async
    func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult
}

public struct ResolvedValue: Codable, Equatable {
    var variant: String?
    var value: Value?
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
