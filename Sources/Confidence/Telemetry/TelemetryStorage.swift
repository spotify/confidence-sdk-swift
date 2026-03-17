import Foundation

struct TelemetryEntry: Codable {
    let flagName: String
    let errorCode: String
    let errorMessage: String?
    let time: Date
    var status: ApplyEventStatus

    init(
        flagName: String,
        errorCode: String,
        errorMessage: String?,
        time: Date,
        status: ApplyEventStatus = .created
    ) {
        self.flagName = flagName
        self.errorCode = errorCode
        self.errorMessage = errorMessage
        self.time = time
        self.status = status
    }
}

struct TelemetryBatch: Codable {
    var entries: [TelemetryEntry]

    var isEmpty: Bool {
        entries.isEmpty
    }

    static func empty() -> TelemetryBatch {
        TelemetryBatch(entries: [])
    }

    static func convertInTransit(batch: TelemetryBatch) -> TelemetryBatch {
        var mutated = batch
        for index in 0..<mutated.entries.count where mutated.entries[index].status == .sending {
            mutated.entries[index].status = .created
        }
        return mutated
    }

    mutating func add(entry: TelemetryEntry) {
        entries.append(entry)
    }

    mutating func setStatus(at index: Int, status: ApplyEventStatus) {
        guard index < entries.count else { return }
        entries[index].status = status
    }

    mutating func removeCompleted() {
        entries.removeAll { $0.status == .sent }
    }
}

protocol TelemetryBatchActor: Actor {
    var batch: TelemetryBatch { get }
    func add(entry: TelemetryEntry) -> TelemetryBatch
    func setStatus(at index: Int, status: ApplyEventStatus) -> TelemetryBatch
    func removeCompleted() -> TelemetryBatch
}

final actor TelemetryBatchInteractor: TelemetryBatchActor {
    var batch: TelemetryBatch

    init(batch: TelemetryBatch) {
        self.batch = TelemetryBatch.convertInTransit(batch: batch)
    }

    func add(entry: TelemetryEntry) -> TelemetryBatch {
        batch.add(entry: entry)
        return batch
    }

    func setStatus(at index: Int, status: ApplyEventStatus) -> TelemetryBatch {
        batch.setStatus(at: index, status: status)
        return batch
    }

    func removeCompleted() -> TelemetryBatch {
        batch.removeCompleted()
        return batch
    }
}
