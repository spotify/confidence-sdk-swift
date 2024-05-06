import Foundation

/// Used to default an enum to the last value if none matches, this should respresent unknown
public protocol CaseIterableDefaultsLast: Decodable & CaseIterable & RawRepresentable
where RawValue: Decodable, AllCases: BidirectionalCollection {}

extension CaseIterableDefaultsLast {
    public init(from decoder: Decoder) throws {
        // All enums should contain at least one item so we allow force unwrap
        // swiftlint:disable:next force_unwrapping
        self = try Self(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? Self.allCases.last!
    }
}
