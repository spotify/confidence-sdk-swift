import Foundation
import OSLog

internal protocol DebugLogger {
    func logEvent(event: ConfidenceEvent, action: String)
    func logMessage(message: String, isWarning: Bool)
    func logFlags(flag: String)
    func logContext(context: ConfidenceStruct)
}

private extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier

    static let confidence = Logger(subsystem: subsystem ?? "", category: "confidence")
}

internal class DebugLoggerImpl: DebugLogger {
    func logMessage(message: String, isWarning: Bool) {
        if !isWarning {
            Logger.confidence.debug("\(message)")
        } else {
            Logger.confidence.warning("\(message)")
        }
    }

    func logEvent(event: ConfidenceEvent, action: String) {
        Logger.confidence.debug("\(action) \(event.name) \(event.payload)")
    }

    func logFlags(flag: String) {
        Logger.confidence.debug("\(flag)")
    }

    func logContext(context: ConfidenceStruct) {
        Logger.confidence.debug("\(context)")
    }
}

public enum LoggerLevel {
    case DEBUG
    case NONE
}
