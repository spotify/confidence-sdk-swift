import Foundation
import OpenFeature
import os

typealias ApplyFlagHTTPResponse = HttpClientResponse<ApplyFlagsResponse>
typealias ApplyFlagResult = Result<ApplyFlagHTTPResponse, Error>

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
            self.triggerBatch()
        }
    }

    public func apply(flagName: String, resolveToken: String) async {
        let applyTime = Date.backport.now
        let eventExists = await cacheDataInteractor.applyEventExists(resolveToken: resolveToken, name: flagName)
        guard eventExists == false else {
            // If record is found in the cache, early return (de-duplication).
            // Triggerring batch apply in case if there are any unsent events stored
            triggerBatch()
            return
        }

        await cacheDataInteractor.add(resolveToken: resolveToken, flagName: flagName, applyTime: applyTime)
        let flagApply = FlagApply(name: flagName, applyTime: applyTime)
        executeApply(resolveToken: resolveToken, items: [flagApply]) { success in
            guard success else {
                self.write(resolveToken: resolveToken, name: flagName, applyTime: applyTime)
                return
            }
            self.triggerBatch()
        }
    }

    // MARK: private

    private func triggerBatch() {
        guard let storedData = try? storage.load(defaultValue: CacheData.empty()), storedData.isEmpty == false else {
            return
        }

        storedData.resolveEvents.forEach { resolveEvent in
            executeApply(
                resolveToken: resolveEvent.resolveToken,
                items: resolveEvent.events
            ) { success in
                guard success else {
                    return
                }
                // Remove events from storage that were successfully sent
                self.remove(resolveToken: resolveEvent.resolveToken)
            }
        }
    }

    private func write(resolveToken: String, name: String, applyTime: Date) {
        guard var storedData = try? storage.load(defaultValue: CacheData.empty()) else {
            return
        }
        storedData.add(resolveToken: resolveToken, flagName: name, applyTime: applyTime)
        try? storage.save(data: storedData)
    }

    private func remove(resolveToken: String) {
        guard var storedData = try? storage.load(defaultValue: CacheData.empty()) else {
            return
        }
        storedData.remove(resolveToken: resolveToken)
        try? storage.save(data: storedData)
    }

    private func executeApply(
        resolveToken: String,
        items: [FlagApply],
        completion: @escaping (Bool) -> Void
    ) {
        let applyFlagRequestItems = items.map { applyEvent in
            AppliedFlagRequestItem(
                flag: applyEvent.name,
                applyTime: applyEvent.applyTime
            )
        }
        let request = ApplyFlagsRequest(
            flags: applyFlagRequestItems,
            sendTime: Date.backport.nowISOString,
            clientSecret: options.credentials.getSecret(),
            resolveToken: resolveToken
        )

        performRequest(request: request) { result in
            switch(result) {
            case .success(_):
                completion(true)
            case .failure(let error):
                self.logApplyError(error: error)
                completion(false)
            }
        }
    }

    private func performRequest(
        request: ApplyFlagsRequest,
        completion: @escaping (ApplyFlagResult) -> Void
    ) {
        do {
            try httpClient.post(path: ":apply", data: request, completion: completion)
        } catch {
            completion(.failure(handleError(error: error)))
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
