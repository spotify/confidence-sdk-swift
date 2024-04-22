import Foundation
import Common

public typealias ConfidenceStruct = [String: ConfidenceValue]

public extension ConfidenceStruct {
    func flattenOpenFeature() -> ConfidenceStruct {
        var newStruct: ConfidenceStruct = [:]
        let openFeatureStruct: ConfidenceValue? = self["open_feature"]
        guard let openFeatureStruct: ConfidenceStruct = openFeatureStruct?.asStructure() else {
            return self
        }
        // add open feature struct keys
        for entry in openFeatureStruct {
            newStruct[entry.key] = entry.value
        }
        // add all the rest keys
        for entry in self where entry.key != "open_feature" {
            newStruct[entry.key] = entry.value
        }
        return newStruct
    }
}

public class ConfidenceValue: Equatable, Codable, CustomStringConvertible {
    private let value: ConfidenceValueInternal
    public var description: String {
        return value.description
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode(ConfidenceValueInternal.self)
    }

    public init(boolean: Bool) {
        self.value = .boolean(boolean)
    }

    public init(string: String) {
        self.value = .string(string)
    }

    public init(integer: Int64) {
        self.value = .integer(integer)
    }

    public init(double: Double) {
        self.value = .double(double)
    }

    /// `date` should have at least precision to the "day".
    /// If a custom TimeZone is set for the input DateComponents, the internal serializers
    /// will convert the input to the local TimeZone before extracting the calendar day.
    public init(date: DateComponents) {
        self.value = .date(date)
    }

    /// If a custom TimeZone is set for the input Date, the internal serializers will convert
    /// the input to the local TimeZone (i.e. the local offset information is maintained
    /// rather than the one customly set in Date).
    public init(timestamp: Date) {
        self.value = .timestamp(timestamp)
    }

    public init(booleanList: [Bool]) {
        self.value = .list(booleanList.map { .boolean($0) })
    }

    public init(stringList: [String]) {
        self.value = .list(stringList.map { .string($0) })
    }


    public init(integerList: [Int64]) {
        self.value = .list(integerList.map { .integer($0) })
    }

    public init(doubleList: [Double]) {
        self.value = .list(doubleList.map { .double($0) })
    }

    public init(nullList: [()]) {
        self.value = .list(nullList.map { .null })
    }

    public init(dateList: [DateComponents]) {
        self.value = .list(dateList.map { .date($0) })
    }

    public init(timestampList: [Date]) {
        self.value = .list(timestampList.map { .timestamp($0) })
    }

    public init(structure: [String: ConfidenceValue]) {
        self.value = .structure(structure.mapValues { $0.value })
    }

    public init(null: ()) {
        self.value = .null
    }

    private init(valueInternal: ConfidenceValueInternal) {
        self.value = valueInternal
    }

    public func asBoolean() -> Bool? {
        if case let .boolean(bool) = value {
            return bool
        }

        return nil
    }

    public func asString() -> String? {
        if case let .string(string) = value {
            return string
        }

        return nil
    }

    public func asInteger() -> Int64? {
        if case let .integer(int64) = value {
            return int64
        }

        return nil
    }

    public func asDouble() -> Double? {
        if case let .double(double) = value {
            return double
        }

        return nil
    }

    public func asDateComponents() -> DateComponents? {
        if case let .date(dateComponents) = value {
            return dateComponents
        }

        return nil
    }

    public func asDate() -> Date? {
        if case let .timestamp(date) = value {
            return date
        }

        return nil
    }

    public func asList() -> [ConfidenceValue]? {
        if case let .list(values) = value {
            return values.map { i in ConfidenceValue(valueInternal: i) }
        }

        return nil
    }

    public func asStructure() -> [String: ConfidenceValue]? {
        if case let .structure(values) = value {
            return values.mapValues { ConfidenceValue(valueInternal: $0) }
        }

        return nil
    }

    public func isNull() -> Bool {
        if case .null = value {
            return true
        }

        return false
    }

    public func type() -> ConfidenceValueType {
        switch value {
        case .boolean:
            return .boolean
        case .string:
            return .string
        case .integer:
            return .integer
        case .double:
            return .double
        case .date:
            return .date
        case .timestamp:
            return .timestamp
        case .list:
            return .list
        case .structure:
            return .structure
        case .null:
            return .null
        }
    }

    public static func == (lhs: ConfidenceValue, rhs: ConfidenceValue) -> Bool {
        lhs.value == rhs.value
    }
}

extension ConfidenceValue {
    public func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

public enum ConfidenceValueType: CaseIterable {
    case boolean
    case string
    case integer
    case double
    case date
    case timestamp
    case list
    case structure
    case null
}


/// Serializable data structure meant for event sending via Confidence
private enum ConfidenceValueInternal: Equatable, Codable {
    case boolean(Bool)
    case string(String)
    case integer(Int64)
    case double(Double)
    case date(DateComponents)
    case timestamp(Date)
    case list([ConfidenceValueInternal])
    case structure([String: ConfidenceValueInternal])
    case null
}

extension ConfidenceValueInternal: CustomStringConvertible {
    public var description: String {
        switch self {
        case .boolean(let value):
            return "\(value)"
        case .string(let value):
            return value
        case .integer(let value):
            return "\(value)"
        case .double(let value):
            return "\(value)"
        case .date(let value):
            return "\(value)"
        case .timestamp(let value):
            return "\(value)"
        case .list(value: let values):
            return "\(values.map { value in value.description })"
        case .structure(value: let values):
            return "\(values.mapValues { value in value.description })"
        case .null:
            return "null"
        }
    }
}
