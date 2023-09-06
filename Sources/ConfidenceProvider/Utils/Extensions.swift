import Foundation
import OpenFeature

/// Used to default an enum to the last value if none matches, this should respresent unknown
protocol CaseIterableDefaultsLast: Decodable & CaseIterable & RawRepresentable
where RawValue: Decodable, AllCases: BidirectionalCollection {}

extension CaseIterableDefaultsLast {
    init(from decoder: Decoder) throws {
        // All enums should contain at least one item so we allow force unwrap
        // swiftlint:disable:next force_unwrapping
        self = try Self(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? Self.allCases.last!
    }
}

extension [ResolvedValue] {
    func toCacheData(context: EvaluationContext, resolveToken: String) -> StoredCacheData {
        var cacheValues: [String: ResolvedValue] = [:]

        forEach { value in
            cacheValues[value.flag] = value
        }

        return StoredCacheData(
            version: InMemoryProviderCache.currentVersion,
            cache: cacheValues,
            curResolveToken: resolveToken,
            curEvalContextHash: context.hash()
        )
    }
}

/// Used for testing
public protocol DispatchQueueType {
    func async(execute work: @escaping @convention(block) () -> Void)
}

extension DispatchQueue: DispatchQueueType {
    public func async(execute work: @escaping @convention(block) () -> Void) {
        async(group: nil, qos: .unspecified, flags: [], execute: work)
    }
}
