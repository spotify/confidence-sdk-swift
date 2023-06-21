import Foundation
import os

public class FlagApplierWithRetries: FlagAppier {
    private var cache = CacheData(data: [:])
    private let readWriteQueue = DispatchQueue(label: "com.confidence.apply.rw")

    private var client: ConfidenceClient
    private let applyQueue: DispatchQueueType
    private let storage: Storage

    init(client: ConfidenceClient, applyQueue: DispatchQueueType, storage: Storage) {
        self.client = client
        self.applyQueue = applyQueue
        self.storage = storage
        self.readFile()
    }

    public func apply(flagName: String, resolveToken: String) {
        let applyTime = Date.backport.now
        self.readWriteQueue.sync {
            self.cache.addEvent(
                resolveToken: resolveToken,
                flagName: flagName,
                applyTime: applyTime
            )
        }
        self.writeToFile()
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
                                self.readWriteQueue.sync {
                                    self.cache.remove(
                                        resolveToken: resolveEntry.key,
                                        flagName: flagEntry.key,
                                        uuid: timeEntry.key
                                    )
                                }
                                self.writeToFile()
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
        self.readWriteQueue.async {
            try? self.storage.save(data: self.cache)
        }
    }

    private func readFile() {
        do {
            // We are reading cache from storage
            let readCache = try self.storage.load(CacheData.self, defaultValue: CacheData(data: [:]))

            // Cache data ==  [String: FlagEvents]
            readCache.data.forEach { resolveToken, flags in

                // FlagEvents == [String: [UUID: Date]]
                flags.data.forEach { flagName, events in

                    // Events == [UUID: Date]
                    events.forEach { id, applyTime in

                        // blocking rwCacheQueue to prevent execution of other tasks on this thread
                        self.readWriteQueue.sync {
                            self.cache.addEvent(
                                resolveToken: resolveToken,
                                flagName: flagName,
                                applyTime: applyTime
                            )
                        }
                    }
                }
            }
        } catch {
            // TODO We shouldn't delete the cache if the read error is transient
        }
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
