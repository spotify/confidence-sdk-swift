import Foundation
import OpenFeature

public protocol KonfidensClient: Resolver {
    func batchResolve(ctx: EvaluationContext) throws -> BatchResolveResult

    func apply(flag: String, resolveToken: String, appliedTime: Date) throws
}

public struct ResolvedValue: Codable, Equatable {
    var variant: String?
    var value: Value?
    var contextHash: String
    var flag: String
    var applyStatus: ApplyStatus
}

public struct BatchResolveResult: Codable, Equatable {
    var resolvedValues: [ResolvedValue]
    var resolveToken: String?
}

public enum ApplyStatus: Codable {
    case notApplied
    case applying
    case applied
    case applyFailed
}
