import Foundation
import os

public class FlagApplierWithRetries: FlagAppier {
    private var cache = CacheData(data: [:])
    private var rwCacheQueue = DispatchQueue(label: "com.confidence.apply.cache.rw", attributes: .concurrent)
    private var rwFileQueue = DispatchQueue(label: "com.confidence.apply.file.rw", attributes: .concurrent)
    private var client: ConfidenceClient
    private let applyQueue: DispatchQueueType
    private let storage: Storage

    init(client: ConfidenceClient, applyQueue: DispatchQueueType, storage: Storage) {
        self.client = client
        self.applyQueue = applyQueue
        self.storage = storage
        rwFileQueue.async(flags: .barrier) {
            self.readFile()
        }
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
        rwFileQueue.async(flags: .barrier) {
            self.writeToFile()
        }
        self.triggerBatch()
    }

    // TODO Define the logic on when / how often to call this function
    // This function should never introduce bad state and any type of error is recoverable on the next try
    private func triggerBatch() {
        do {
            // TODO Batch apply events
            self.cache.data.forEach { resolveEntry in
                resolveEntry.value.data.forEach { flagEntry in
                    flagEntry.value.forEach { timeEntry in
                        executeApply(
                            flag: flagEntry.key,
                            resolveToken: resolveEntry.key,
                            applyTime: timeEntry.value
                        ) { success in
                            if success {
                                _ = self.rwCacheQueue.sync(flags: .barrier) {
                                    self.cache.data[resolveEntry.key]?.data[flagEntry.key]?.removeValue(
                                        forKey: timeEntry.key)
                                }
                                self.rwFileQueue.async(flags: .barrier) {
                                    self.writeToFile()
                                }
                            } else {
                                // "triggerBatch" should not introduce bad state in case of any failure, will retry later
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

    private func writeToFile() {
        do {
            let data = self.rwCacheQueue.sync {
                return self.cache.data.filter { _, entries in
                    !entries.data.values.allSatisfy { events in
                        events.isEmpty
                    }
                }
            }
            try self.storage.save(data: data)
        } catch {
            // Best effort writing to storage, nothing to do here
        }
    }

    private func readFile() {
        do {
            let readCache = try storage.load(CacheData.self, defaultValue: CacheData(data: [:]))
            readCache.data.forEach { resolveToken, flags in
                flags.data.forEach { flagName, events in
                    events.forEach { id, applyTime in
                        self.rwCacheQueue.sync(flags: .barrier) {
                            if let resolveTokenData = self.cache.data[resolveToken] {
                                if resolveTokenData.data[flagName] != nil {
                                    self.cache.data[resolveToken]?.data[flagName]?[id] = applyTime
                                } else {
                                    self.cache.data[resolveToken]?.data[flagName] = [id: applyTime]
                                }
                            } else {
                                let eventEntry = [id: applyTime]
                                self.cache.data[resolveToken] = FlagEvents(data: [flagName: eventEntry])
                            }
                        }
                    }
                }
            }
        } catch {
            // TODO We shouldn't delete the cache if the read error is transient
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
