import Combine
import Foundation
import OpenFeature
import os

public class PersistentBatchProviderCache: BatchProviderCache {
    private var rwCacheQueue = DispatchQueue(label: "com.konfidens.cache.rw", attributes: .concurrent)
    private static let currentVersion = "0.0.1"
    private static let persistIntervalSeconds = RunLoop.SchedulerTimeType.Stride.seconds(30.0)

    private var storage: Storage
    private var cache: [ResolvedKey: ResolvedValue]
    private var curResolveToken: String?
    private var persistPublisher = PassthroughSubject<CacheEvent, Never>()
    private var cancellable = Set<AnyCancellable>()

    init(storage: Storage, cache: [ResolvedKey: ResolvedValue], curResolveToken: String?) {
        self.storage = storage
        self.cache = cache
        self.curResolveToken = curResolveToken

        persistPublisher
            .throttle(
                for: PersistentBatchProviderCache.persistIntervalSeconds, scheduler: RunLoop.current, latest: true
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
        guard !ctx.getTargetingKey().isEmpty else {
            throw OpenFeatureError.targetingKeyMissingError
        }

        let key = ResolvedKey(flag: flag, targetingKey: ctx.getTargetingKey())

        return try rwCacheQueue.sync {
            if let value = self.cache[key] {
                guard let curResolveToken = curResolveToken else {
                    throw KonfidensError.noResolveTokenFromCache
                }
                return .init(
                    resolvedValue: value, needsUpdate: value.contextHash != ctx.hash(), resolveToken: curResolveToken)
            } else {
                return nil
            }
        }
    }

    public func clearAndSetValues(values: [ResolvedValue], ctx: EvaluationContext, resolveToken: String) throws {
        guard !ctx.getTargetingKey().isEmpty else {
            throw OpenFeatureError.targetingKeyMissingError
        }

        rwCacheQueue.sync(flags: .barrier) {
            self.cache = [:]
            self.curResolveToken = resolveToken
            values.forEach { value in
                let key = ResolvedKey(flag: value.flag, targetingKey: ctx.getTargetingKey())
                self.cache[key] = value
            }
        }
        self.persistPublisher.send(.persist)
    }

    public func updateApplyStatus(flag: String, ctx: EvaluationContext, resolveToken: String, applyStatus: ApplyStatus)
        throws
    {
        guard !ctx.getTargetingKey().isEmpty else {
            throw OpenFeatureError.targetingKeyMissingError
        }

        let key = ResolvedKey(flag: flag, targetingKey: ctx.getTargetingKey())
        try rwCacheQueue.sync(flags: .barrier) {
            guard var value = self.cache[key] else {
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
            self.cache[key] = value
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

    public static func fromDefaultStorage() -> PersistentBatchProviderCache {
        return from(storage: DefaultStorage())
    }

    public static func from(storage: Storage) -> PersistentBatchProviderCache {
        do {
            let storedCache = try storage.load(
                StoredCacheData.self,
                defaultValue: StoredCacheData(version: currentVersion, cache: [:], curResolveToken: nil))
            return PersistentBatchProviderCache(
                storage: storage, cache: storedCache.cache, curResolveToken: storedCache.curResolveToken)
        } catch {
            Logger(subsystem: "com.konfidens.cache", category: "storage").error(
                "Error when trying to load resolver cache, clearing cache: \(error)")

            if case .corruptedCache = error as? KonfidensError {
                try? storage.clear()
            }

            return PersistentBatchProviderCache(storage: storage, cache: [:], curResolveToken: nil)
        }
    }
}

extension PersistentBatchProviderCache {
    struct StoredCacheData: Codable {
        var version: String
        var cache: [ResolvedKey: ResolvedValue]
        var curResolveToken: String?
    }

    enum CacheEvent {
        case persist
    }

    func persist() throws {
        try rwCacheQueue.sync {
            try self.storage.save(
                data: StoredCacheData(
                    version: PersistentBatchProviderCache.currentVersion,
                    cache: self.cache,
                    curResolveToken: self.curResolveToken))
        }
    }

    public struct ResolvedKey: Hashable, Codable {
        var flag: String
        var targetingKey: String
    }
}
