import Foundation
import Common
import Confidence
import OpenFeature

@testable import ConfidenceProvider

public class AlwaysFailCache: ProviderCache {
    public func getValue(
        flag: String, contextHash: String
    ) throws -> CacheGetValueResult? {
        throw ConfidenceError.cacheError(message: "Always Fails (getValue)")
    }

    public func clearAndSetValues(
        values: [ResolvedValue], ctx: EvaluationContext, resolveToken: String
    ) throws {
        // no-op
    }
}
