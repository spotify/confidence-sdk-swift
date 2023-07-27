import Foundation

final actor CacheDataInteractor: CacheDataActor {
    private let storage: Storage
    var cache = CacheData.empty()

    init(storage: Storage) {
        self.storage = storage

        Task {
            await loadCacheFromStorage()
        }
    }

    func add(resolveToken: String, flagName: String, applyTime: Date) -> CacheData {
        if cache.isEmpty == false {
            cache.add(resolveToken: resolveToken, flagName: flagName, applyTime: applyTime)
        } else {
            cache = CacheData(
                resolveToken: resolveToken,
                flagName: flagName,
                applyTime: applyTime
            )
        }
        return cache
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

    func setEventSent(resolveToken: String, name: String) -> CacheData {
        cache.setEventSent(resolveToken: resolveToken, name: name)
        return cache
    }

    func setEventSent(resolveToken: String) -> CacheData {
        cache.setEventSent(resolveToken: resolveToken)
        return cache
    }

    private func loadCacheFromStorage() {
        guard let storedData = try? storage.load(defaultValue: cache),
              storedData.isEmpty == false else {
            return
        }
        self.cache = storedData
    }
}
