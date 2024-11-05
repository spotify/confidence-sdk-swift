import Foundation

protocol TelemetryManager {
    func incrementStaleAccess()
    func getSnapshot() -> TelemetryPayload
}

class Telemetry: TelemetryManager {
    private let queue = DispatchQueue(label: "com.confidence.telemetry_manager")
    private var staleAccessCounter = 0;

    public init() {}

    static public let shared: TelemetryManager = Telemetry()

    public func getSnapshot() -> TelemetryPayload {
        return queue.sync {
            TelemetryPayload(staleAccess: getStaleAccessAndReset())
        }
    }

    public func incrementStaleAccess() {
        queue.sync {
            staleAccessCounter += 1
        }
    }

    private func getStaleAccessAndReset() -> Int {
        return queue.sync {
            let currentCounter = staleAccessCounter
            staleAccessCounter = 0;
            return currentCounter
        }
    }
}
