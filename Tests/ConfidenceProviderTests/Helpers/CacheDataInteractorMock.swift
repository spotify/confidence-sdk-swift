import Foundation

@testable import ConfidenceProvider

final actor CacheDataInteractorMock: CacheDataActor {
    var cache = CacheData.empty()

    func add(resolveToken: String, flagName: String, applyTime: Date) {}

    func remove(resolveToken: String, flagName: String) {}

    func remove(resolveToken: String) {}

    func applyEventExists(resolveToken: String, name: String) -> Bool {
        return false
    }

    func setEventSent(resolveToken: String, name: String) {}

    func loadCacheFromStorage() {}
}
