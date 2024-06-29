import Foundation
import os

typealias ApplyFlagHTTPResponse = HttpClientResponse<ApplyFlagsResponse>
typealias ApplyFlagResult = Result<ApplyFlagHTTPResponse, Error>

final class FlagApplierWithRetries: FlagApplier {
    private let storage: Storage
    private let httpClient: HttpClient
    private let options: ConfidenceClientOptions
    private let cacheDataInteractor: CacheDataActor
    private let metadata: ConfidenceMetadata
    private let debugLogger: DebugLogger?

    init(
        httpClient: HttpClient,
        storage: Storage,
        options: ConfidenceClientOptions,
        metadata: ConfidenceMetadata,
        cacheDataInteractor: CacheDataActor? = nil,
        triggerBatch: Bool = true,
        debugLogger: DebugLogger? = nil
    ) {
        self.storage = storage
        self.httpClient = httpClient
        self.options = options
        self.metadata = metadata
        self.debugLogger = debugLogger

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

        debugLogger?.logFlags(action: "Apply", flag: flagName)
        self.writeToFile(data: data)
        await triggerBatch()
    }

    // MARK: private

    private func triggerBatch() async {
        let cacheData = await cacheDataInteractor.cache
        await cacheData.resolveEvents.asyncForEach { resolveEvent in
            let appliesToSend = resolveEvent.events.filter { $0.status == .created }
                .chunk(size: 20)

            guard appliesToSend.isEmpty == false else {
                return
            }

            await appliesToSend.asyncForEach { chunk in
                await self.writeStatus(resolveToken: resolveEvent.resolveToken, events: chunk, status: .sending)
                let success = await executeApply(
                    resolveToken: resolveEvent.resolveToken,
                    items: chunk
                )
                guard success else {
                    await self.writeStatus(resolveToken: resolveEvent.resolveToken, events: chunk, status: .created)
                    return
                }
                // Set 'sent' property of apply events to true
                await self.writeStatus(resolveToken: resolveEvent.resolveToken, events: chunk, status: .sent)
            }
        }
    }

    private func writeStatus(resolveToken: String, events: [FlagApply], status: ApplyEventStatus) async {
        let lastIndex = events.count - 1
        await events.enumerated().asyncForEach { index, event in
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

    private func writeToFile(data: CacheData) {
        try? storage.save(data: data)
    }

    private func executeApply(
        resolveToken: String,
        items: [FlagApply]
    ) async -> Bool {
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
            resolveToken: resolveToken,
            sdk: Sdk(id: metadata.name, version: metadata.version)
        )

        let result = await performRequest(request: request)
        switch result {
        case .success:
            return true
        case .failure(let error):
            self.logApplyError(error: error)
            return false
        }
    }

    private func performRequest(
        request: ApplyFlagsRequest
    ) async -> ApplyFlagResult {
        do {
            return try await httpClient.post(path: ":apply", data: request)
        } catch {
            return .failure(handleError(error: error))
        }
    }

    private func handleError(error: Error) -> Error {
        if error is ConfidenceError {
            return error
        } else {
            return ConfidenceError.grpcError(message: "\(error)")
        }
    }

    private func logApplyError(error: Error) {
        Logger(subsystem: "com.confidence.provider", category: "apply").error(
            "Error while executing \"apply\": \(error)")
    }
}

extension Sequence {
    func asyncForEach(
        _ transform: (Element) async throws -> Void
    ) async rethrows {
        for element in self {
            try await transform(element)
        }
    }
}
