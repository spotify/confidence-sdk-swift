import Foundation
import OSLog

protocol DebugLogger {
    func logEvent(action: String, event: ConfidenceEvent?)
    func logMessage(message: String, isWarning: Bool)
    func logFlags(action: String, flag: String)
    func logFlags(action: String, context: ConfidenceStruct)
    func logContext(action: String, context: ConfidenceStruct)
    func logResolveDebugURL(flagName: String, context: ConfidenceStruct)
}

private extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier

    static let confidence = Logger(subsystem: subsystem ?? "", category: "confidence")
}

class DebugLoggerImpl: DebugLogger {
    private let encoder = JSONEncoder()
    let clientKey: String

    func logResolveDebugURL(flagName: String, context: ConfidenceStruct) {
        let ctxNetworkValue: NetworkStruct = TypeMapper.convert(structure: context)
        do {
            let ctxNetworkData = try encoder.encode(ctxNetworkValue)

            let resolveHintData = try [
                "context": JSONSerialization.jsonObject(with: ctxNetworkData, options: []),
                "flag": "flags/\(flagName)",
                "clientKey": clientKey,
            ]
            let jsonData = try JSONSerialization.data(withJSONObject: resolveHintData, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                let base64 = Data(jsonString.utf8).base64EncodedString()
                let message = """
                    Check your flag evaluation for \(flagName)
                    by copy pasting the payload to the Resolve tester '\(base64)'
                """
                log(messageLevel: .DEBUG, message: message)
            } else {
                log(messageLevel: .DEBUG, message: "Could not convert JSON data to string")
            }
        } catch {
            log(messageLevel: .DEBUG, message: "Failed to encode resolve hint data: \(error)")
        }
    }

    let loggerLevel: LoggerLevel

    init(loggerLevel: LoggerLevel, clientKey: String) {
        self.loggerLevel = loggerLevel
        self.clientKey = clientKey
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

    func logFlags(action: String, context: ConfidenceStruct) {
        log(messageLevel: .TRACE, message: "[\(action)] \(context)")
    }

    func logContext(action: String, context: ConfidenceStruct) {
        log(messageLevel: .TRACE, message: "[\(action)] \(context)")
    }

    func log(messageLevel: LoggerLevel, message: String) {
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
