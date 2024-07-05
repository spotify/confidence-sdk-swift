import Foundation

@testable import Confidence

internal class DebugLoggerFake: DebugLogger {
    private let uploadSuccessCounter = ThreadSafeCounter()

    func logEvent(action: String, event: ConfidenceEvent?) {
        // no-op
    }

    func logMessage(message: String, isWarning: Bool) {
        if message == "Event upload: HTTP status 200" {
            uploadSuccessCounter.increment()
        }
    }

    func logFlags(action: String, flag: String) {
        // no-op
    }

    func logContext(action: String, context: ConfidenceStruct) {
        // no-op
    }

    func getUploadSuccessCount() -> Int {
        return uploadSuccessCounter.get()
    }

    func waitUploadSuccessCount(value: Int32, timeout: TimeInterval) throws {
        try uploadSuccessCounter.waitUntil(value: value, timeout: timeout)
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

            // TODO There might be more efficient ways than a while true loop
            repeat {
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
