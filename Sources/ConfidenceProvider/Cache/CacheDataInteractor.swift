import Foundation

final actor CacheDataInteractor: CacheDataActor {
    var cache = CacheData.empty()

    init(cacheData: CacheData) {
        cache = CacheData.convertInTransit(cache: cacheData)
    }

    func add(resolveToken: String, flagName: String, applyTime: Date) -> (CacheData, Bool) {
        if cache.isEmpty == false {
            let added = cache.add(resolveToken: resolveToken, flagName: flagName, applyTime: applyTime)
            return (cache, added)
        } else {
            cache = CacheData(
                resolveToken: resolveToken,
                flagName: flagName,
                applyTime: applyTime
            )
            return (cache, true)
        }
    }

    func remove(resolveToken: String, flagName: String) {
        cache.remove(resolveToken: resolveToken, flagName: flagName)
    }

    func remove(resolveToken: String) {
        cache.remove(resolveToken: resolveToken)
    }

    func applyEventExists(resolveToken: String, name: String) -> Bool {
        cache.applyEventExists(resolveToken: resolveToken, name: name)
    }

    func setEventStatus(resolveToken: String, name: String, status: ApplyEventStatus) -> CacheData {
        cache.setEventStatus(resolveToken: resolveToken, name: name, status: status)
        return cache
    }

    func setEventStatus(resolveToken: String, status: ApplyEventStatus) -> CacheData {
        cache.setEventStatus(resolveToken: resolveToken, status: status)
        return cache
    }
}
