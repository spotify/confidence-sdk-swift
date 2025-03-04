import Foundation
import OSLog

internal protocol DebugLogger {
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

internal class DebugLoggerImpl: DebugLogger {
    private let encoder = JSONEncoder()
    private let clientKey: String

    func logResolveDebugURL(flagName: String, context: ConfidenceStruct) {
        let ctxNetworkValue = TypeMapper.convert(structure: context)
        if let ctxNetworkData = try? encoder.encode(ctxNetworkValue),
        let ctxNetworkString = String(data: ctxNetworkData, encoding: .utf8) {
            var url = URLComponents()
            url.scheme = "https"
            url.host = "app.confidence.spotify.com"
            url.path = "/flags/resolver-test"
            url.queryItems = [
                URLQueryItem(name: "client-key", value: clientKey),
                URLQueryItem(name: "flag", value: "flags/\(flagName)"),
                URLQueryItem(name: "context", value: "\(ctxNetworkString)"),
            ]
            log(messageLevel: .DEBUG, message: """
                See resolves for \(flagName) in Confidence:
                \(url.url?.absoluteString ?? "N/A")
            """)
        }
    }

    private let loggerLevel: LoggerLevel

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
