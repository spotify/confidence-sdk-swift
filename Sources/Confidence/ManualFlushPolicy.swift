import Foundation

let manualFlushEvent = ConfidenceEvent(name: "manual_flush", payload: [:], eventTime: Date.backport.now)

class ManualFlushPolicy: FlushPolicy {
    private var flushRequested = false

    func reset() {
        flushRequested = false
    }

    func hit(event: ConfidenceEvent) {
        flushRequested = event.name == manualFlushEvent.name
    }

    func shouldFlush() -> Bool {
        return flushRequested
    }
}
