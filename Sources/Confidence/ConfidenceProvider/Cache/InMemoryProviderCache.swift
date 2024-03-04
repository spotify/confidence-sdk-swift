import Combine
import Foundation
import OpenFeature
import os

public class InMemoryProviderCache: ProviderCache {
    private var rwCacheQueue = DispatchQueue(label: "com.confidence.cache.rw", attributes: .concurrent)
    static let currentVersion = "0.0.1"
    private let cache: [String: ResolvedValue]

    private var storage: Storage
    private var curResolveToken: String?
    private var curEvalContextHash: String?

    init(storage: Storage, cache: [String: ResolvedValue], curResolveToken: String?, curEvalContextHash: String?) {
        self.storage = storage
        self.cache = cache
        self.curResolveToken = curResolveToken
        self.curEvalContextHash = curEvalContextHash
    }

    public func getValue(flag: String, ctx: EvaluationContext) throws -> CacheGetValueResult? {
        if let value = self.cache[flag] {
            guard let curResolveToken = curResolveToken else {
                throw ConfidenceError.noResolveTokenFromCache
            }
            return .init(
                resolvedValue: value, needsUpdate: curEvalContextHash != ctx.hash(), resolveToken: curResolveToken)
        } else {
            return nil
        }
    }

    public static func from(storage: Storage) -> InMemoryProviderCache {
        do {
            let storedCache = try storage.load(
                defaultValue: StoredCacheData(
                    version: currentVersion, cache: [:], curResolveToken: nil, curEvalContextHash: nil))
            return InMemoryProviderCache(
                storage: storage,
                cache: storedCache.cache,
                curResolveToken: storedCache.curResolveToken,
                curEvalContextHash: storedCache.curEvalContextHash)
        } catch {
            Logger(subsystem: "com.confidence.cache", category: "storage").error(
                "Error when trying to load resolver cache, clearing cache: \(error)")

            if case .corruptedCache = error as? ConfidenceError {
                try? storage.clear()
            }

            return InMemoryProviderCache(storage: storage, cache: [:], curResolveToken: nil, curEvalContextHash: nil)
        }
    }
}

public struct ResolvedKey: Hashable, Codable {
    var flag: String
    var targetingKey: String
}

struct StoredCacheData: Codable {
    var version: String
    var cache: [String: ResolvedValue]
    var curResolveToken: String?
    var curEvalContextHash: String?
}
