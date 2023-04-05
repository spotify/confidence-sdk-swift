import Combine
import Foundation
import OpenFeature
import os

public class PersistentProviderCache: ProviderCache {
    private var rwCacheQueue = DispatchQueue(label: "com.konfidens.cache.rw", attributes: .concurrent)
    private static let currentVersion = "0.0.1"
    private static let persistIntervalSeconds = RunLoop.SchedulerTimeType.Stride.seconds(30.0)

    private var storage: Storage
    private var cache: [String: ResolvedValue]
    private var curResolveToken: String?
    private var curEvalContextHash: String?
    private var persistPublisher = PassthroughSubject<CacheEvent, Never>()
    private var cancellable = Set<AnyCancellable>()

    init(storage: Storage, cache: [String: ResolvedValue], curResolveToken: String?, curEvalContextHash: String?) {
        self.storage = storage
        self.cache = cache
        self.curResolveToken = curResolveToken
        self.curEvalContextHash = curEvalContextHash

        persistPublisher
            .throttle(
                for: PersistentProviderCache.persistIntervalSeconds, scheduler: RunLoop.current, latest: true
            )
            .sink { _ in
                do {
                    try self.persist()
                } catch {
                    Logger(subsystem: "com.konfidens.cache", category: "persist")
                        .error("Unable to persist cache: \(error)")
                }
            }
            .store(in: &cancellable)
    }

    public func getValue(flag: String, ctx: EvaluationContext) throws -> CacheGetValueResult? {
        return try rwCacheQueue.sync {
            if let value = self.cache[flag] {
                guard let curResolveToken = curResolveToken else {
                    throw KonfidensError.noResolveTokenFromCache
                }
                return .init(
                    resolvedValue: value, needsUpdate: curEvalContextHash != ctx.hash(), resolveToken: curResolveToken)
            } else {
                return nil
            }
        }
    }

    public func clearAndSetValues(values: [ResolvedValue], ctx: EvaluationContext, resolveToken: String) throws {
        rwCacheQueue.sync(flags: .barrier) {
            self.cache = [:]
            self.curResolveToken = resolveToken
            self.curEvalContextHash = ctx.hash()
            values.forEach { value in
                self.cache[value.flag] = value
            }
        }
        self.persistPublisher.send(.persist)
    }

    public func updateApplyStatus(flag: String, ctx: EvaluationContext, resolveToken: String, applyStatus: ApplyStatus)
        throws
    {
        if ctx.hash() != curEvalContextHash {
            throw KonfidensError.cachedValueExpired
        }

        try rwCacheQueue.sync(flags: .barrier) {
            guard var value = self.cache[flag] else {
                throw KonfidensError.flagNotFoundInCache
            }

            guard resolveToken == curResolveToken else {
                throw KonfidensError.cachedValueExpired
            }

            switch applyStatus {
            case .applying:
                if value.applyStatus == .applying || value.applyStatus == .applied {
                    throw KonfidensError.applyStatusTransitionError
                }
            case .applied, .applyFailed:
                if value.applyStatus != .applying {
                    throw KonfidensError.applyStatusTransitionError
                }
            case .notApplied:
                throw KonfidensError.applyStatusTransitionError
            }

            value.applyStatus = applyStatus
            self.cache[flag] = value
        }
        self.persistPublisher.send(.persist)
    }

    public func clear() throws {
        try rwCacheQueue.sync(flags: .barrier) {
            try self.storage.clear()
            self.cache = [:]
            self.curResolveToken = nil
        }
    }

    public static func fromDefaultStorage() -> PersistentProviderCache {
        return from(storage: DefaultStorage())
    }

    public static func from(storage: Storage) -> PersistentProviderCache {
        do {
            let storedCache = try storage.load(
                StoredCacheData.self,
                defaultValue: StoredCacheData(
                    version: currentVersion, cache: [:], curResolveToken: nil, curEvalContextHash: nil))
            return PersistentProviderCache(
                storage: storage,
                cache: storedCache.cache,
                curResolveToken: storedCache.curResolveToken,
                curEvalContextHash: storedCache.curEvalContextHash)
        } catch {
            Logger(subsystem: "com.konfidens.cache", category: "storage").error(
                "Error when trying to load resolver cache, clearing cache: \(error)")

            if case .corruptedCache = error as? KonfidensError {
                try? storage.clear()
            }

            return PersistentProviderCache(storage: storage, cache: [:], curResolveToken: nil, curEvalContextHash: nil)
        }
    }
}

extension PersistentProviderCache {
    struct StoredCacheData: Codable {
        var version: String
        var cache: [String: ResolvedValue]
        var curResolveToken: String?
        var curEvalContextHash: String?
    }

    enum CacheEvent {
        case persist
    }

    func persist() throws {
        try rwCacheQueue.sync {
            try self.storage.save(
                data: StoredCacheData(
                    version: PersistentProviderCache.currentVersion,
                    cache: self.cache,
                    curResolveToken: self.curResolveToken,
                    curEvalContextHash: self.curEvalContextHash))
        }
    }

    public struct ResolvedKey: Hashable, Codable {
        var flag: String
        var targetingKey: String
    }
}
