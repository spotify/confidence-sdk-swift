import Foundation

/**
Flag resolve configuration related to how to refresh flags at startup
*/
public enum InitializationStrategy {
    /**
    Flags are resolved before the values are accessible by the application
    */
    case fetchAndActivate
    /**
    Values in the cache are accessible right away, an asynchronous resolve
    updates the cache for a future session
    */
    case activateAndFetchAsync
}
