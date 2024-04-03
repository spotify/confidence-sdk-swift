import Foundation

public typealias ConfidenceStruct = [String: ConfidenceValue]

/// Serializable data structure meant for event sending via Confidence
public enum ConfidenceValue: Equatable, Encodable {
    case boolean(Bool)
    case string(String)
    case integer(Int64)
    case double(Double)
    case date(DateComponents)
    case timestamp(Date)
    case list([ConfidenceValue])
    case structure([String: ConfidenceValue])
    case null

    public func asBoolean() -> Bool? {
        if case let .boolean(bool) = self {
            return bool
        }

        return nil
    }

    public func asString() -> String? {
        if case let .string(string) = self {
            return string
        }

        return nil
    }

    public func asInteger() -> Int64? {
        if case let .integer(int64) = self {
            return int64
        }

        return nil
    }

    public func asDouble() -> Double? {
        if case let .double(double) = self {
            return double
        }

        return nil
    }

    public func asDateComponents() -> DateComponents? {
        if case let .date(dateComponents) = self {
            return dateComponents
        }

        return nil
    }

    public func asDate() -> Date? {
        if case let .timestamp(date) = self {
            return date
        }

        return nil
    }

    public func asList() -> [ConfidenceValue]? {
        if case let .list(values) = self {
            return values
        }

        return nil
    }

    public func asStructure() -> [String: ConfidenceValue]? {
        if case let .structure(values) = self {
            return values
        }

        return nil
    }

    public func isNull() -> Bool {
        if case .null = self {
            return true
        }

        return false
    }
}

extension ConfidenceValue: CustomStringConvertible {
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

extension ConfidenceValue {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null:
            try container.encodeNil()
        case .integer(let integer):
            try container.encode(integer)
        case .double(let double):
            try container.encode(double)
        case .string(let string):
            try container.encode(string)
        case .boolean(let boolean):
            try container.encode(boolean)
        case .date(let dateComponents):
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd-MM-yyyy"
            if let date = Calendar.current.date(from: dateComponents) {
                try container.encode(dateFormatter.string(from: date))
            } else {
                throw ConfidenceError.internalError(message: "Could not create date from components")
            }
        case .timestamp(let date):
            let isoFormatter = ISO8601DateFormatter()
            let formattedDate = isoFormatter.string(from: date)
            try container.encode(formattedDate)
        case .structure(let structure):
            try container.encode(structure)
        case .list(let list):
            try container.encode(list)
        }
    }
}
