import Foundation

protocol TelemetryManager {
    func incrementStaleAccess()
    func incrementFlagTypeMismatch()
    func getSnapshot() -> Data
}

class Telemetry: TelemetryManager {
    private let queue = DispatchQueue(label: "com.confidence.telemetry_manager")
    private var staleAccessCounter: Int32 = 0;
    private var flagTypeMismatchCounter: Int32 = 0;

    public init() {}

    static public let shared: TelemetryManager = Telemetry.init()

    public func getSnapshot() -> Data {
        // Initialize your data using the generated types
        var countTrace1 = CountTrace()
        countTrace1.traceID = .traceStale
        countTrace1.count = getStaleAccessAndReset()

        var countTrace2 = CountTrace()
        countTrace2.traceID = .traceTypeMismatch
        countTrace2.count = getFlagTypeMismatchAndReset()

        var libraryData = LibraryData()
        libraryData.countTraces = [countTrace1, countTrace2]
        libraryData.libraryID = .sdkSwiftCore
        libraryData.libraryVersion = "1.0.1"
        libraryData.durationsTraces = []
        do {
            return try libraryData.serializedData()
        } catch {
            print("Failed to encode telemetry data: \(error)")
            return Data()
        }
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

    private func getStaleAccessAndReset() -> Int32 {
        return queue.sync {
            let currentCounter = staleAccessCounter
            staleAccessCounter = 0;
            return currentCounter
        }
    }

    private func getFlagTypeMismatchAndReset() -> Int32 {
        return queue.sync {
            let currentCounter = flagTypeMismatchCounter
            flagTypeMismatchCounter = 0;
            return currentCounter
        }
    }
}
