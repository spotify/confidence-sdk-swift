import Foundation

class SizeFlushPolicy: FlushPolicy {
    private var currentSize = 0
    private let batchSize: Int

    init(batchSize: Int) {
        self.batchSize = batchSize
    }

    func reset() {
        currentSize = 0
    }

    func hit(event: ConfidenceEvent) {
        currentSize += 1
    }

    func shouldFlush() -> Bool {
        currentSize >= batchSize
    }
}
