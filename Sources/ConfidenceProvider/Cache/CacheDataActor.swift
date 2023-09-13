import Foundation

/// `CacheDataActor` protocol defines an actor responsible for interactions with `CacheData`.
/// Implementation of CacheDataActor is thread-safe by default.
protocol CacheDataActor: Actor {
    var cache: CacheData { get }

    /// Adds single data entry to the cache.
    func add(resolveToken: String, flagName: String, applyTime: Date) -> (CacheData, Bool)

    /// Removes data from the cache.
    /// - Note: This method removes all flag apply entries from cache for given resolve token.
    func remove(resolveToken: String)

    /// Removes single apply event from the cache.
    func remove(resolveToken: String, flagName: String)

    /// Removes single apply event from the cache.
    func applyEventExists(resolveToken: String, name: String) -> Bool

    /// Sets Flag Apply Event `status`.
    func setEventStatus(resolveToken: String, name: String, status: ApplyEventStatus) -> CacheData

    /// Sets Resolve Apply Event `status` property.
    func setEventStatus(resolveToken: String, status: ApplyEventStatus) -> CacheData
}
