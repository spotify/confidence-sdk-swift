import Foundation

/// The status of the flag resolution on disk according to a storage check.
public enum ResolveStorageStatus: Equatable {
    case empty
    case stale(lastFetchedAt: Date?)
    case fresh(lastFetchedAt: Date?)
}

/// Metadata for the stored resolution, independent of the currently activated values.
public struct ResolveStorageMetadata {
    public let isEmpty: Bool
    public let lastFetchedAt: Date?
    public let context: ConfidenceStruct

    public init(isEmpty: Bool, lastFetchedAt: Date?, context: ConfidenceStruct) {
        self.isEmpty = isEmpty
        self.lastFetchedAt = lastFetchedAt
        self.context = context
    }
}

public protocol ResolveStorageCheck {
    func check(metadata: ResolveStorageMetadata) -> ResolveStorageStatus
}

/// Treats unknown fetch times and ages at or beyond `maxAge` as stale.
public struct MaxAgeStorageCheck: ResolveStorageCheck {
    public let maxAge: TimeInterval
    private let now: () -> Date

    /// - Parameter maxAge: A positive, finite maximum age in seconds.
    public init(maxAge: TimeInterval) {
        self.init(maxAge: maxAge, now: Date.init)
    }

    internal init(maxAge: TimeInterval, now: @escaping () -> Date) {
        precondition(maxAge > 0 && maxAge.isFinite, "maxAge must be positive and finite")
        self.maxAge = maxAge
        self.now = now
    }

    public func check(metadata: ResolveStorageMetadata) -> ResolveStorageStatus {
        if metadata.isEmpty {
            return .empty
        }
        guard let fetchedAt = metadata.lastFetchedAt else {
            return .stale(lastFetchedAt: nil)
        }
        return now().timeIntervalSince(fetchedAt) >= maxAge
            ? .stale(lastFetchedAt: fetchedAt)
            : .fresh(lastFetchedAt: fetchedAt)
    }
}
