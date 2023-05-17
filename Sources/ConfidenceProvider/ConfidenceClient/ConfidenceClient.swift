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
}

public struct ResolvesResult: Codable, Equatable {
    var resolvedValues: [ResolvedValue]
    var resolveToken: String?
}
