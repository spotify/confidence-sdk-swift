import Foundation

@testable import ConfidenceProvider

final actor CacheDataInteractorMock: CacheDataActor {
    func setEventSent(resolveToken: String) -> ConfidenceProvider.CacheData {
        return cache
    }

    var cache = CacheData.empty()

    func add(resolveToken: String, flagName: String, applyTime: Date) -> ConfidenceProvider.CacheData {
        return cache
    }

    func remove(resolveToken: String, flagName: String) {}

    func remove(resolveToken: String) {}

    func applyEventExists(resolveToken: String, name: String) -> Bool {
        return false
    }

    func setEventSent(resolveToken: String, name: String) -> ConfidenceProvider.CacheData {
        return cache
    }
}
