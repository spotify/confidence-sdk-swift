import Foundation
import OpenFeature
import os

final class FlagApplierWithRetries: FlagApplier {
    private let storage: Storage
    private let httpClient: HttpClient
    private let options: ConfidenceClientOptions
    private let cacheDataInteractor: CacheDataActor

    init(
        httpClient: HttpClient,
        storage: Storage,
        options: ConfidenceClientOptions,
        cacheDataInteractor: CacheDataActor? = nil,
        triggerBatch: Bool = true
    ) {
        self.storage = storage
        self.httpClient = httpClient
        self.options = options
        self.cacheDataInteractor = cacheDataInteractor ?? CacheDataInteractor(storage: storage)

        if triggerBatch {
            Task {
                await self.triggerBatch()
            }
        }
    }

    public func apply(flagName: String, resolveToken: String) async {
        let applyTime = Date.backport.now
        let eventExists = await cacheDataInteractor.applyEventExists(resolveToken: resolveToken, name: flagName)
        guard eventExists == false else {
            // If record is found in the cache, early return without taking further action (de-duplication).
            return
        }

        await cacheDataInteractor.add(resolveToken: resolveToken, flagName: flagName, applyTime: applyTime)
        let flagApply = FlagApply(name: flagName, applyTime: applyTime)
        executeApply(resolveToken: resolveToken, items: [flagApply]) { success in
            guard success else {
                self.write(resolveToken: resolveToken, name: flagName, applyTime: applyTime)
                return
            }
            Task {
                await self.cacheDataInteractor.setEventSent(resolveToken: resolveToken, name: flagName)
            }
        }
    }

    // MARK: private

    private func triggerBatch() async {
        let cache = await cacheDataInteractor.cache
        guard cache.isEmpty == false else {
            return
        }

        cache.resolveEvents.forEach { resolveEvent in
            executeApply(
                resolveToken: resolveEvent.resolveToken,
                items: resolveEvent.events
            ) { success in
                guard success else {
                    return
                }
                self.remove(resolveToken: resolveEvent.resolveToken)
                resolveEvent.events.forEach { applyEvent in
                    Task {
                        await self.cacheDataInteractor.setEventSent(
                            resolveToken: resolveEvent.resolveToken,
                            name: applyEvent.name
                        )
                    }
                }
            }
        }
    }

    private func write(resolveToken: String, name: String, applyTime: Date) {
        do {
            var storedData = try storage.load(defaultValue: CacheData.empty())
            storedData.add(resolveToken: resolveToken, flagName: name, applyTime: applyTime)
            try storage.save(data: storedData)
        } catch {}
    }

    private func remove(resolveToken: String) {
        do {
            var storedData = try storage.load(defaultValue: CacheData.empty())
            storedData.remove(resolveToken: resolveToken)
            try storage.save(data: storedData)
        } catch {}
    }

    private func executeApply(resolveToken: String, items: [FlagApply], completion: @escaping (Bool) -> Void) {
        let applyFlagRequestItems = items.map { applyEvent in
            AppliedFlagRequestItem(
                flag: applyEvent.name,
                applyTime: applyEvent.applyEvent.applyTime
            )
        }
        let request = ApplyFlagsRequest(
            flags: applyFlagRequestItems,
            sendTime: Date.backport.nowISOString,
            clientSecret: options.credentials.getSecret(),
            resolveToken: resolveToken
        )

        do {
            try performRequest(request: request)
            completion(true)
        } catch {
            self.logApplyError(error: error)
            completion(false)
        }
    }

    private func performRequest(request: ApplyFlagsRequest) throws {
        do {
            let result = try self.httpClient.post(path: ":apply", data: request, resultType: ApplyFlagsResponse.self)
            guard result.response.status == .ok else {
                throw result.response.mapStatusToError(error: result.decodedError)
            }
        } catch let error {
            throw handleError(error: error)
        }
    }

    private func handleError(error: Error) -> Error {
        if error is ConfidenceError || error is OpenFeatureError {
            return error
        } else {
            return ConfidenceError.grpcError(message: "\(error)")
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
