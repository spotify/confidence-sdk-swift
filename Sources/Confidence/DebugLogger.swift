import Foundation
import OSLog

internal protocol DebugLogger {
    func logEvent(action: String, event: ConfidenceEvent?)
    func logMessage(message: String, isWarning: Bool)
    func logFlags(action: String, flag: String)
    func logContext(action: String, context: ConfidenceStruct)
    func logResolveDebugURL(flagName: String, context: ConfidenceStruct)
}

private extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier

    static let confidence = Logger(subsystem: subsystem ?? "", category: "confidence")
}

internal class DebugLoggerImpl: DebugLogger {
    private let encoder = JSONEncoder()

    func logResolveDebugURL(flagName: String, context: ConfidenceStruct) {
        let ctxNetworkValue = TypeMapper.convert(structure: context)
        if let ctxNetworkData = try? encoder.encode(ctxNetworkValue),
        let ctxNetworkString = String(data: ctxNetworkData, encoding: .utf8) {
            log(messageLevel: .DEBUG, message: "[Resolve Debug] https://app.confidence.spotify.com/flags/resolver-test?flag=flags/\(flagName)&context=\(ctxNetworkString)")
        }
    }

    private let loggerLevel: LoggerLevel

    init(loggerLevel: LoggerLevel) {
        self.loggerLevel = loggerLevel
    }

    func logMessage(message: String, isWarning: Bool = false) {
        if isWarning {
            log(messageLevel: .WARN, message: message)
        } else {
            log(messageLevel: .DEBUG, message: message)
        }
    }

    func logEvent(action: String, event: ConfidenceEvent?) {
        log(messageLevel: .DEBUG, message: "[\(action)] \(event?.name ?? "")")
    }

    func logFlags(action: String, flag: String) {
        log(messageLevel: .TRACE, message: "[\(action)] \(flag)")
    }

    func logContext(action: String, context: ConfidenceStruct) {
        log(messageLevel: .TRACE, message: "[\(action)] \(context)")
    }

    private func log(messageLevel: LoggerLevel, message: String) {
        if messageLevel >= loggerLevel {
            switch messageLevel {
            case .TRACE:
                Logger.confidence.trace("\(message)")
            case .DEBUG:
                Logger.confidence.debug("\(message)")
            case .WARN:
                Logger.confidence.warning("\(message)")
            case .ERROR:
                Logger.confidence.error("\(message)")
            case .NONE:
                // do nothing
                break
            }
        }
    }
}

public enum LoggerLevel: Comparable {
    case TRACE
    case DEBUG
    case WARN
    case ERROR
    case NONE
}
