import Foundation

protocol TelemetryManager {
    func incrementStaleAccess()
    func incrementFlagTypeMismatch()
    func getSnapshot() -> TelemetryPayload
}

class Telemetry: TelemetryManager {
    private let queue = DispatchQueue(label: "com.confidence.telemetry_manager")
    private var staleAccessCounter = 0;
    private var flagTypeMismatchCounter = 0;

    public init() {}

    static public let shared: TelemetryManager = Telemetry.init()

    public func getSnapshot() -> TelemetryPayload {
        TelemetryPayload(
            libraryId: ConfidenceMetadata.defaultMetadata.id,
            libraryVersion: ConfidenceMetadata.defaultMetadata.version,
            countTraces: [
                CountTrace.init(traceId: TraceId.staleAccess, count: getStaleAccessAndReset()),
                CountTrace.init(traceId: TraceId.typeMismatch, count: getFlagTypeMismatchAndReset()),
            ],
            durationsTraces: [])
    }

    public func incrementStaleAccess() {
        queue.sync {
            staleAccessCounter += 1
        }
    }

    public func incrementFlagTypeMismatch() {
        queue.sync {
            flagTypeMismatchCounter += 1
        }
    }

    private func getStaleAccessAndReset() -> Int {
        return queue.sync {
            let currentCounter = staleAccessCounter
            staleAccessCounter = 0;
            return currentCounter
        }
    }

    private func getFlagTypeMismatchAndReset() -> Int {
        return queue.sync {
            let currentCounter = flagTypeMismatchCounter
            flagTypeMismatchCounter = 0;
            return currentCounter
        }
    }
}
