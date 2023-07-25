import Foundation
import OpenFeature

public class LocalStorageResolver: Resolver {
    private var cache: ProviderCache

    init(cache: ProviderCache) {
        self.cache = cache
    }

    public func resolve(flag: String, ctx: EvaluationContext) throws -> ResolveResult {
        let getResult = try self.cache.getValue(flag: flag, ctx: ctx)
        guard let getResult = getResult else {
            throw OpenFeatureError.flagNotFoundError(key: flag)
        }
        guard getResult.needsUpdate == false else {
            throw ConfidenceError.cachedValueExpired
        }
        return .init(resolvedValue: getResult.resolvedValue, resolveToken: getResult.resolveToken)
    }
}
