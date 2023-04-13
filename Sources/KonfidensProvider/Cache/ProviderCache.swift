import Foundation
import OpenFeature

public protocol ProviderCache {
    func getValue(flag: String, ctx: EvaluationContext) throws -> CacheGetValueResult?

    func clearAndSetValues(values: [ResolvedValue], ctx: EvaluationContext, resolveToken: String) throws

    func updateApplyStatus(flag: String, ctx: EvaluationContext, resolveToken: String, applyStatus: ApplyStatus) throws
        -> Bool
}

public struct CacheGetValueResult {
    var resolvedValue: ResolvedValue
    var needsUpdate: Bool
    var resolveToken: String
}
