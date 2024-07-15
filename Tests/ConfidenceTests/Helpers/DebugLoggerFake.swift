import Foundation

@testable import Confidence

internal class DebugLoggerFake: DebugLogger {
    private let uploadBatchSuccessCounter = ThreadSafeCounter()
    public var uploadedEvents: [String] = [] // Holds the "eventDefinition" name of each uploaded event

    func logEvent(action: String, event: ConfidenceEvent?) {
        // no-op
    }

    func logMessage(message: String, isWarning: Bool) {
        if message.starts(with: "Event upload: HTTP status 200") {
            uploadedEvents.append(contentsOf: parseEvents(fromString: message))
            uploadBatchSuccessCounter.increment()
        }
    }

    func logFlags(action: String, flag: String) {
        // no-op
    }

    func logContext(action: String, context: ConfidenceStruct) {
        // no-op
    }

    func getUploadBatchSuccessCount() -> Int {
        return uploadBatchSuccessCounter.get()
    }

    func waitUploadBatchSuccessCount(value: Int32, timeout: TimeInterval) throws {
        try uploadBatchSuccessCounter.waitUntil(value: value, timeout: timeout)
    }

    /**
    Example
    Input: "Event upload: HTTP status 200. Events: event-name1, event-name2"
    Output: ["event-name1", "event-name2"]
    */
    private func parseEvents(fromString message: String) -> [String] {
        guard let eventsStart = message.range(of: "Events:") else {
            return []
        }

        let startIndex = message.index(eventsStart.upperBound, offsetBy: 1)
        let endIndex = message.endIndex
        let eventsString = message[startIndex..<endIndex]

        return eventsString.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private class ThreadSafeCounter {
        private let queue = DispatchQueue(label: "ThreadSafeCounterQueue")
        private var count = 0

        func increment() {
            queue.sync {
                count += 1
            }
        }

        func get() -> Int {
            queue.sync {
                return count
            }
        }

        func waitUntil(value: Int32, timeout: TimeInterval) throws {
            let deadline = DispatchTime.now() + timeout

            repeat {
                Thread.sleep(forTimeInterval: 0.1) // Shortcut to reduce CPU usage, probably needs refactoring
                guard deadline > DispatchTime.now() else {
                    throw TimeoutError(message: "Timed out waiting for counter to reach \(value)")
                }
                if (queue.sync {
                    count >= value
                }) {
                    return
                }
            } while true
        }
    }

    struct TimeoutError: Error {
        let message: String
    }
}
