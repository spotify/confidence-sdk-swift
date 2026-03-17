import Foundation

protocol TelemetryProducer {
    func report(flagName: String, errorCode: ErrorCode, errorMessage: String?) async
}
