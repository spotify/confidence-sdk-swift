import Foundation
import os

public class FlagApplierWithRetries: FlagAppier {
    private var cache = CacheData(data: [:])
    private var rwCacheQueue = DispatchQueue(label: "com.confidence.apply.cache.rw", attributes: .concurrent)
    private var client: ConfidenceClient
    private let applyQueue: DispatchQueueType
    private let storage: Storage

    init(client: ConfidenceClient, applyQueue: DispatchQueueType, storage: Storage) {
        self.client = client
        self.applyQueue = applyQueue
        self.storage = storage
        readFile()
    }

    public func apply(flagName: String, resolveToken: String) {
            let applyTime = Date.backport.now
        self.rwCacheQueue.sync(flags: .barrier) {
            if let resolveTokenData = self.cache.data[resolveToken] {
                if resolveTokenData.data[flagName] != nil {
                    self.cache.data[resolveToken]?.data[flagName]?[UUID()] = applyTime
                } else {
                    self.cache.data[resolveToken]?.data[flagName] = [UUID(): applyTime]
                }
            } else {
                let eventEntry = [UUID(): applyTime]
                self.cache.data[resolveToken] = FlagEvents(data: [flagName: eventEntry])
            }
        }
        // Serial writes, but blockingo
        self.writeToFile()
        // TODO Revisit when to call triggerBatch
        self.triggerBatch()
    }

    private func triggerBatch() {
        do {
            // TODO Batch
            self.cache.data.forEach { resolveEntry in
                resolveEntry.value.data.forEach { flagEntry in
                    flagEntry.value.forEach { timeEntry in
                        executeApply(flag: flagEntry.key, resolveToken: resolveEntry.key, applyTime: timeEntry.value) { success in
                            if success {
                                self.rwCacheQueue.async(flags: .barrier) {
                                    self.cache.data[resolveEntry.key]?.data[flagEntry.key]?.removeValue(forKey: timeEntry.key)
                                }
                            } else {
                                // TODO
                            }
                        }
                    }
                }
            }
        }
    }

    private func executeApply(
        flag: String, resolveToken: String, applyTime: Date, completion: @escaping (Bool) -> Void
    ) {
        applyQueue.async {
            do {
                try self.client.apply(flag: flag, resolveToken: resolveToken, applyTime: applyTime)
                completion(true)
            } catch let error {
                self.logApplyError(error: error)
                completion(false)
            }
        }
    }

    struct CacheData: Codable {
        // resolveToken -> data
        var data: [String: FlagEvents]
    }

    struct FlagEvents: Codable {
        // flagName -> [event time]
        var data: [String: [UUID: Date]]
    }

    private func writeToFile() {
        self.rwCacheQueue.async(flags: .barrier) {
            do {
                try self.storage.save(data: self.cache)
            } catch {
                // TODO
            }
        }
    }

    private func readFile() {
        do {
            self.cache = try storage.load(CacheData.self, defaultValue: CacheData(data: [:]))
        } catch {}
    }

    private func logApplyError(error: Error) {
        switch error {
        case ConfidenceError.applyStatusTransitionError, ConfidenceError.cachedValueExpired,
            ConfidenceError.flagNotFoundInCache:
            Logger(subsystem: "com.confidence.provider", category: "apply").debug(
                "Cache data for flag was updated while executing \"apply\", aborting")
        default:
            Logger(subsystem: "com.confidence.provider", category: "apply").error(
                "Error while executing \"apply\": \(error)")
        }
    }
}
