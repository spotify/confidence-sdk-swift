import Foundation

/// Flag resolve configuration related to how to refresh flags at startup
public enum InitializationStrategy {
    case fetchAndActivate, activateAndFetchAsync
}
