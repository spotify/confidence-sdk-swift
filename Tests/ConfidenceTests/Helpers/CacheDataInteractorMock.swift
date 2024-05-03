import Foundation

@testable import Confidence

final actor CacheDataInteractorMock: CacheDataActor {
    var cache = CacheData.empty()

    func add(resolveToken: String, flagName: String, applyTime: Date) -> (CacheData, Bool) {
        return (cache, true)
    }

    func remove(resolveToken: String, flagName: String) {}

    func remove(resolveToken: String) {}

    func applyEventExists(resolveToken: String, name: String) -> Bool {
        return false
    }

    func setEventStatus(resolveToken: String, name: String, status: ApplyEventStatus) -> CacheData {
        cache
    }

    func setEventStatus(resolveToken: String, status: ApplyEventStatus) -> CacheData {
        cache
    }
}
