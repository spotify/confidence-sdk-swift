import Foundation
import os

public class FlagApplierWithRetries: FlagAppier {
    private var cache = CacheData(data: [:])
    private var rwCacheQueue = DispatchQueue(label: "com.confidence.apply.cache.rw", attributes: .concurrent)
    private var client: ConfidenceClient
    private let applyQueue: DispatchQueueType

    init(client: ConfidenceClient, applyQueue: DispatchQueueType) {
        self.client = client
        self.applyQueue = applyQueue
        readFile()
    }

    public func apply(flagName: String, resolveToken: String) {
        applyQueue.async {
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
                self.writeToFile()
            }
            // TODO Revisit when to call triggerBatch
            self.triggerBatch()
        }
    }

    private func triggerBatch() {
        do {
            // TODO Batch
            try self.cache.data.forEach { resolveEntry in
                try resolveEntry.value.data.forEach { flagEntry in
                    try flagEntry.value.forEach { timeEntry in
                        try self.client.apply(
                            flag: flagEntry.key, resolveToken: resolveEntry.key, applyTime: timeEntry.value)
                        rwCacheQueue.async(flags: .barrier) {
                            self.cache.data[resolveEntry.key]?.data[flagEntry.key]?.removeValue(forKey: timeEntry.key)
                        }
                    }
                }
            }
        } catch let error {
            logApplyError(error: error)
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
        // TODO
    }

    private func readFile() {
        // TODO
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
