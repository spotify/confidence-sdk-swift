import Foundation

public enum ConfidenceError: Error, Equatable {
    case grpcError(message: String)
    case cacheError(message: String)
    case corruptedCache(message: String)
    case flagNotFoundError(key: String)
    case badRequest(message: String?)
    case internalError(message: String)
    case parseError(message: String)
    case invalidContextInMessage
}

extension ConfidenceError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .grpcError(let message):
            return message
        case .cacheError(let message):
            return message
        case .corruptedCache(let message):
            return message
        case .flagNotFoundError(let key):
            return "Flag not found for key \(key)"
        case .badRequest(let message):
            guard let message = message else {
                return "Bad request from provider"
            }
            return "Bad request from provider: \(message)"
        case .internalError(let message):
            return "An internal error occurred: \(message)"
        case .parseError(let message):
            return "Parse error occurred: \(message)"
        case .invalidContextInMessage:
            return "Field 'context' is not allowed in event's data"
        }
    }
}
