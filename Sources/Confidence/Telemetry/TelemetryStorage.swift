import Foundation

struct TelemetryCounterState: Codable {
    var resolveRates: [String: UInt32]
    var clientErrors: [String: UInt32]

    static func empty() -> TelemetryCounterState {
        TelemetryCounterState(resolveRates: [:], clientErrors: [:])
    }

    var isEmpty: Bool {
        resolveRates.isEmpty && clientErrors.isEmpty
    }

    func toResolveRateRecords() -> [ResolveRateRecord] {
        resolveRates.map { ResolveRateRecord(count: $0.value, reason: $0.key) }
            .sorted { $0.reason < $1.reason }
    }

    func toClientErrorRateRecords() -> [ClientErrorRateRecord] {
        clientErrors.map { ClientErrorRateRecord(count: $0.value, errorCode: $0.key) }
            .sorted { $0.errorCode < $1.errorCode }
    }
}

protocol TelemetryCounterActor: Actor {
    var currentState: TelemetryCounterState { get }
    func recordResolve(reason: String)
    func recordClientError(errorCode: String)
    func drain() -> TelemetryCounterState
    func restore(state: TelemetryCounterState)
}

final actor TelemetryCounterInteractor: TelemetryCounterActor {
    private var state: TelemetryCounterState

    var currentState: TelemetryCounterState { state }

    init(state: TelemetryCounterState) {
        self.state = state
    }

    func recordResolve(reason: String) {
        state.resolveRates[reason, default: 0] += 1
    }

    func recordClientError(errorCode: String) {
        state.clientErrors[errorCode, default: 0] += 1
    }

    func drain() -> TelemetryCounterState {
        let snapshot = state
        state = .empty()
        return snapshot
    }

    func restore(state: TelemetryCounterState) {
        for (key, count) in state.resolveRates {
            self.state.resolveRates[key, default: 0] += count
        }
        for (key, count) in state.clientErrors {
            self.state.clientErrors[key, default: 0] += count
        }
    }
}
