import Foundation
import OpenFeature

extension [ResolvedValue] {
    func toCacheData(context: EvaluationContext, resolveToken: String) -> StoredCacheData {
        var cacheValues: [String: ResolvedValue] = [:]

        forEach { value in
            cacheValues[value.flag] = value
        }

        return StoredCacheData(
            version: InMemoryProviderCache.currentVersion,
            cache: cacheValues,
            curResolveToken: resolveToken,
            curEvalContextHash: context.hash()
        )
    }
}

/// Used for testing
public protocol DispatchQueueType {
    func async(execute work: @escaping @convention(block) () -> Void)
}

extension DispatchQueue: DispatchQueueType {
    public func async(execute work: @escaping @convention(block) () -> Void) {
        async(group: nil, qos: .unspecified, flags: [], execute: work)
    }
}
