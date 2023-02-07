import Foundation

final class UnfairLock {
    private var _lock: UnsafeMutablePointer<os_unfair_lock>

    init() {
        _lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        _lock.initialize(to: os_unfair_lock())
    }

    deinit {
        _lock.deallocate()
    }

    func locked<T>(_ code: () throws -> T) rethrows -> T {
        os_unfair_lock_lock(_lock)
        defer { os_unfair_lock_unlock(_lock) }
        return try code()
    }
}
