import Foundation

@testable import Confidence

enum CacheDataUtility {
    /// Helper method for unit testing code that involves cache data.
    /// - Parameter date: The reference date for apply events. Defaults to a date representing 1000 seconds since January 1, 1970.
    /// - Parameter resolveEventCount: The number of resolve events to include in the prefilled data. Defaults to 1.
    /// - Parameter applyEventCount: The number of apply events to include in the prefilled data. Defaults to 3.
    /// - Throws: An error if any issues occur during the creation of the prefilled data.
    /// - Returns: The prefilled data as an instance of `Data`.
    /// - Note:`applyEventCount` takes an effect on all every resolve events.
    static func prefilledCacheData(
        date: Date = Date(timeIntervalSince1970: 1000),
        resolveEventCount: Int = 1,
        applyEventCount: Int = 3
    ) throws -> CacheData {
        var cacheData = CacheData.empty()
        for resolveIndex in 0..<resolveEventCount {
            let resolveToken = "token\(resolveIndex)"
            var applyEvents: [FlagApply] = []

            for applyEventIndex in 0..<applyEventCount {
                let flagName = "prefilled\(applyEventIndex)"
                if cacheData.isEmpty {
                    let applyEvent = FlagApply(name: flagName, applyTime: date)
                    applyEvents.append(applyEvent)
                } else {
                    _ = cacheData.add(resolveToken: resolveToken, flagName: flagName, applyTime: date)
                }
            }

            if cacheData.isEmpty {
                cacheData = CacheData(resolveToken: resolveToken, events: applyEvents)
            }
        }
        return cacheData
    }
}
