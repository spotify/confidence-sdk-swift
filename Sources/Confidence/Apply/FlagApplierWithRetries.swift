import Foundation
import os

typealias FlagLogsHTTPResponse = HttpClientResponse<WriteFlagLogsResponse>
typealias FlagLogsResult = Result<FlagLogsHTTPResponse, Error>

final class FlagApplierWithRetries: FlagApplier, TelemetryProducer {
    private let applyStorage: Storage
    private let telemetryStorage: Storage
    private let httpClient: HttpClient
    private let options: ConfidenceClientOptions
    private let cacheDataInteractor: CacheDataActor
    private let telemetryInteractor: TelemetryBatchActor
    private let metadata: ConfidenceMetadata
    private let debugLogger: DebugLogger?

    init(
        httpClient: HttpClient,
        applyStorage: Storage,
        telemetryStorage: Storage,
        options: ConfidenceClientOptions,
        metadata: ConfidenceMetadata,
        cacheDataInteractor: CacheDataActor? = nil,
        telemetryInteractor: TelemetryBatchActor? = nil,
        triggerBatch: Bool = true,
        debugLogger: DebugLogger? = nil
    ) {
        self.applyStorage = applyStorage
        self.telemetryStorage = telemetryStorage
        self.httpClient = httpClient
        self.options = options
        self.metadata = metadata
        self.debugLogger = debugLogger

        let storedApplyData = try? applyStorage.load(defaultValue: CacheData.empty())
        self.cacheDataInteractor = cacheDataInteractor
            ?? CacheDataInteractor(cacheData: storedApplyData ?? .empty())

        let storedTelemetry = try? telemetryStorage.load(defaultValue: TelemetryBatch.empty())
        self.telemetryInteractor = telemetryInteractor
            ?? TelemetryBatchInteractor(batch: storedTelemetry ?? .empty())

        if triggerBatch {
            Task {
                await self.triggerBatch()
            }
        }
    }

    // MARK: FlagApplier

    public func apply(flagName: String, resolveToken: String) async {
        let applyTime = Date.backport.now
        let (data, added) = await cacheDataInteractor.add(
            resolveToken: resolveToken,
            flagName: flagName,
            applyTime: applyTime
        )
        guard added == true else {
            await triggerBatch()
            return
        }

        debugLogger?.logFlags(action: "Apply", flag: flagName)
        writeApplyToFile(data: data)
        await triggerBatch()
    }

    // MARK: TelemetryProducer

    func report(flagName: String, errorCode: ErrorCode, errorMessage: String?) async {
        let entry = TelemetryEntry(
            flagName: flagName,
            errorCode: errorCode.serialized,
            errorMessage: errorMessage,
            time: Date.backport.now
        )
        let batch = await telemetryInteractor.add(entry: entry)
        writeTelemetryToFile(batch: batch)
        debugLogger?.logMessage(
            message: "Telemetry reported: \(errorCode.serialized) for flag '\(flagName)'",
            isWarning: false
        )
        await triggerBatch()
    }

    // MARK: Private

    private func triggerBatch() async {
        await sendApplyBatches()
        await sendTelemetryBatch()
    }

    private func sendApplyBatches() async {
        let cacheData = await cacheDataInteractor.cache
        await cacheData.resolveEvents.asyncForEach { resolveEvent in
            let appliesToSend = resolveEvent.events.filter { $0.status == .created }
                .chunk(size: 20)

            guard appliesToSend.isEmpty == false else {
                return
            }

            await appliesToSend.asyncForEach { chunk in
                await self.writeApplyStatus(
                    resolveToken: resolveEvent.resolveToken, events: chunk, status: .sending
                )
                let success = await self.executeFlagLogs(
                    resolveToken: resolveEvent.resolveToken,
                    items: chunk
                )
                guard success else {
                    await self.writeApplyStatus(
                        resolveToken: resolveEvent.resolveToken, events: chunk, status: .created
                    )
                    return
                }
                await self.writeApplyStatus(
                    resolveToken: resolveEvent.resolveToken, events: chunk, status: .sent
                )
            }
        }
    }

    private func sendTelemetryBatch() async {
        let currentBatch = await telemetryInteractor.batch
        let pending = currentBatch.entries.enumerated().filter { $0.element.status == .created }

        guard !pending.isEmpty else { return }

        let chunks = pending.chunk(size: 20)
        for chunk in chunks {
            let indices = chunk.map { $0.offset }
            let entries = chunk.map { $0.element }

            for index in indices {
                _ = await telemetryInteractor.setStatus(at: index, status: .sending)
            }

            let success = await executeTelemetryOnly(entries: entries)
            if success {
                for index in indices {
                    _ = await telemetryInteractor.setStatus(at: index, status: .sent)
                }
            } else {
                for index in indices {
                    _ = await telemetryInteractor.setStatus(at: index, status: .created)
                }
            }
        }

        let updatedBatch = await telemetryInteractor.removeCompleted()
        writeTelemetryToFile(batch: updatedBatch)
    }

    private func writeApplyStatus(
        resolveToken: String, events: [FlagApply], status: ApplyEventStatus
    ) async {
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
                try? self.applyStorage.save(data: data)
            }
        }
    }

    private func writeApplyToFile(data: CacheData) {
        try? applyStorage.save(data: data)
    }

    private func writeTelemetryToFile(batch: TelemetryBatch) {
        try? telemetryStorage.save(data: batch)
    }

    private func makeSdkInfo() -> SdkInfo {
        SdkInfo(id: metadata.name, version: metadata.version)
    }

    private func executeFlagLogs(
        resolveToken: String,
        items: [FlagApply]
    ) async -> Bool {
        let appliedFlags = items.map { event in
            AppliedFlag(
                flag: "flags/\(event.name)",
                applyTime: Date.backport.toISOString(date: event.applyTime)
            )
        }
        let sdkInfo = makeSdkInfo()
        let flagAssigned = FlagAssignedEvent(
            resolveId: resolveToken,
            clientInfo: ClientInfo(sdk: sdkInfo),
            flags: appliedFlags
        )
        let request = WriteFlagLogsRequest(
            flagAssigned: [flagAssigned],
            telemetryData: TelemetryData(sdk: sdkInfo)
        )

        let result = await performRequest(request: request)
        switch result {
        case .success:
            return true
        case .failure(let error):
            logError(error: error)
            return false
        }
    }

    private func executeTelemetryOnly(entries: [TelemetryEntry]) async -> Bool {
        let sdkInfo = makeSdkInfo()
        let request = WriteFlagLogsRequest(
            flagAssigned: nil,
            telemetryData: TelemetryData(sdk: sdkInfo)
        )

        let result = await performRequest(request: request)
        switch result {
        case .success:
            return true
        case .failure(let error):
            logError(error: error)
            return false
        }
    }

    private func performRequest(
        request: WriteFlagLogsRequest
    ) async -> FlagLogsResult {
        do {
            return try await httpClient.post(path: ":write", data: request)
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

    private func logError(error: Error) {
        debugLogger?.logMessage(
            message: "Error while sending flag logs: \(error)", isWarning: true
        )
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
