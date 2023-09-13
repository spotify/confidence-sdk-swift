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

        let storedData = try? storage.load(defaultValue: CacheData.empty())
        self.cacheDataInteractor = cacheDataInteractor ?? CacheDataInteractor(cacheData: storedData ?? .empty())

        if triggerBatch {
            Task(priority: .utility) {
                await self.triggerBatch()
            }
        }
    }

    public func apply(flagName: String, resolveToken: String) async {
        let applyTime = Date.backport.now
        let (data, added) = await cacheDataInteractor.add(
            resolveToken: resolveToken,
            flagName: flagName,
            applyTime: applyTime
        )
        guard added == true else {
            // If record is found in the cache, early return (de-duplication).
            // Triggerring batch apply in case if there are any unsent events stored
            await triggerBatch()
            return
        }

        self.writeToFile(data: data)
        await triggerBatch()
    }

    // MARK: private

    private func triggerBatch() async {
        async let cacheData = await cacheDataInteractor.cache
        await cacheData.resolveEvents.forEach { resolveEvent in
            let appliesToSend = resolveEvent.events.filter { $0.status == .created }
                .chunk(size: 20)

            guard appliesToSend.isEmpty == false else {
                return
            }

            appliesToSend.forEach { chunk in
                self.writeStatus(resolveToken: resolveEvent.resolveToken, events: chunk, status: .sending)
                executeApply(
                    resolveToken: resolveEvent.resolveToken,
                    items: chunk
                ) { success in
                    guard success else {
                        self.writeStatus(resolveToken: resolveEvent.resolveToken, events: chunk, status: .created)
                        return
                    }
                    // Set 'sent' property of apply events to true
                    self.writeStatus(resolveToken: resolveEvent.resolveToken, events: chunk, status: .sent)
                }
            }
        }
    }

    private func writeStatus(resolveToken: String, events: [FlagApply], status: ApplyEventStatus) {
        let lastIndex = events.count - 1
        events.enumerated().forEach { index, event in
            Task(priority: .medium) {
                var data = await self.cacheDataInteractor.setEventStatus(
                    resolveToken: resolveToken,
                    name: event.name,
                    status: status
                )

                if index == lastIndex {
                    let unsentFlagApplies = data.resolveEvents.filter {
                        $0.isSent == false
                    }
                    data.resolveEvents = unsentFlagApplies
                    try? self.storage.save(data: data)
                }
            }
        }
    }

    private func writeToFile(data: CacheData) {
        try? storage.save(data: data)
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
            switch result {
            case .success:
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
