import Foundation
import OpenFeature

@testable import Confidence

public class AlwaysFailCache: ProviderCache {
    public func getValue(
        flag: String, ctx: EvaluationContext
    ) throws -> CacheGetValueResult? {
        throw ConfidenceError.cacheError(message: "Always Fails (getValue)")
    }

    public func clearAndSetValues(
        values: [ResolvedValue], ctx: EvaluationContext, resolveToken: String
    ) throws {
        // no-op
    }
}
