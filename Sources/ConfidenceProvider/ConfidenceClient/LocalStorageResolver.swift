import Foundation
import Common
import Confidence
import OpenFeature

public class LocalStorageResolver: Resolver {
    private var cache: ProviderCache

    init(cache: ProviderCache) {
        self.cache = cache
    }

    public func resolve(flag: String, contextHash: String) throws -> ResolveResult {
        let getResult = try self.cache.getValue(flag: flag, contextHash: contextHash)
        guard let getResult = getResult else {
            throw OpenFeatureError.flagNotFoundError(key: flag)
        }
        guard getResult.needsUpdate == false else {
            var resolveValueStale = getResult.resolvedValue
            resolveValueStale.resolveReason = .stale
            return .init(resolvedValue: resolveValueStale, resolveToken: getResult.resolveToken)
        }
        return .init(resolvedValue: getResult.resolvedValue, resolveToken: getResult.resolveToken)
    }
}
