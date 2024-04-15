import Foundation

public enum ConfidenceError: Error, Equatable {
    /// Signifies that the provider is not connected to the Confidence backend
    case providerNotConnected
    /// GRPC-specific error during the connection
    case grpcError(message: String)
    /// Error while caching a resolve or retrieving a cached resolve
    case cacheError(message: String)
    /// Corrupted cache file
    case corruptedCache(message: String)
    /// Flag not found in cache
    case flagNotFoundInCache
    /// Value in cache expired
    case cachedValueExpired
    /// Apply state transition not allowed
    case applyStatusTransitionError
    /// No resolveToken returned by the server
    case noResolveTokenFromServer
    /// No resolveToken in the cache
    case noResolveTokenFromCache
    /// Bad request from provider
    case badRequest(message: String?)
    /// Internal error
    case internalError(message: String)
}

extension ConfidenceError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .providerNotConnected:
            return "The provider is not connected"
        case .grpcError(let message):
            return message
        case .cacheError(let message):
            return message
        case .corruptedCache(let message):
            return message
        case .flagNotFoundInCache:
            return "Flag not found in the cache"
        case .cachedValueExpired:
            return "Cached flag has an old evaluation context"
        case .applyStatusTransitionError:
            return "Apply status transition error"
        case .noResolveTokenFromServer:
            return "No resolver token returned by the server"
        case .noResolveTokenFromCache:
            return "No resolver token in cache, cache needs refresh"
        case .badRequest(let message):
            guard let message = message else {
                return "Bad request from provider"
            }
            return "Bad request from provider: \(message)"
        case .internalError(let message):
            return "An internal error occurred: \(message)"
        }
    }
}
