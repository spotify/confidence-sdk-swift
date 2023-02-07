import Foundation
import OpenFeature

public class LocalStorageResolver: Resolver {
    private var cache: BatchProviderCache

    init(cache: BatchProviderCache) {
        self.cache = cache
    }

    public func resolve(flag: String, ctx: EvaluationContext) throws -> ResolveResult {
        let getResult = try self.cache.getValue(flag: flag, ctx: ctx)
        guard let getResult = getResult else {
            throw KonfidensError.flagNotFoundInCache
        }
        guard !getResult.needsUpdate else {
            throw KonfidensError.cachedValueExpired
        }
        return .init(resolvedValue: getResult.resolvedValue, resolveToken: getResult.resolveToken)
    }
}
