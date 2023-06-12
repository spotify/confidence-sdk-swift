import Foundation
import OpenFeature

public protocol ConfidenceClient: Resolver {
    func resolve(ctx: EvaluationContext) throws -> ResolvesResult

    func apply(flag: String, resolveToken: String, applyTime: Date) throws
}

public struct ResolvedValue: Codable, Equatable {
    var variant: String?
    var value: Value?
    var flag: String
    var applyStatus: ApplyStatus
    var resolveReason: Reason

    enum Reason: Int, Codable, Equatable {
        case match = 0
        case noMatch = 1
        case targetingKeyError = 2
        case generalError = 3
        case disabled = 4
    }
}

public struct ResolvesResult: Codable, Equatable {
    var resolvedValues: [ResolvedValue]
    var resolveToken: String?
}

public enum ApplyStatus: Codable {
    case notApplied
    case applying
    case applied
    case applyFailed
}
