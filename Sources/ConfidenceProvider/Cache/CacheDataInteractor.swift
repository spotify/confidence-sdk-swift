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

    func add(resolveToken: String, flagName: String, applyTime: Date) {
        if cache.isEmpty == false {
            cache.add(resolveToken: resolveToken, flagName: flagName, applyTime: applyTime)
        } else {
            cache = CacheData(
                resolveToken: resolveToken,
                flagName: flagName,
                applyTime: applyTime
            )
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

    private func loadCacheFromStorage() {
        guard let storedData = try? storage.load(defaultValue: cache),
              storedData.isEmpty == false else {
            return
        }
        self.cache = storedData
    }
}
