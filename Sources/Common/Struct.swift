import Foundation

public struct Struct: Equatable {
    public init(fields: [String: StructValue]) {
        self.fields = fields
    }
    public var fields: [String: StructValue]
}

public enum StructValue: Equatable {
    case null
    case integer(Int64)
    case string(String)
    case double(Double)
    case number(Double)
    case boolean(Bool)
    case date(DateComponents)
    case timestamp(Date)
    case structure(Struct)
    case list([StructValue])
}

extension StructValue: Codable {
    // swiftlint:disable:next cyclomatic_complexity
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null:
            try container.encodeNil()
        case .integer(let integer):
            try container.encode(integer)
        case .double(let double):
            try container.encode(double)
        case .number(let double):
            try container.encode(double)
        case .string(let string):
            try container.encode(string)
        case .boolean(let boolean):
            try container.encode(boolean)
        case .date(let dateComponents):
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.timeZone = TimeZone.current
            dateFormatter.formatOptions = [.withFullDate]
            if let date = Calendar.current.date(from: dateComponents) {
                try container.encode(dateFormatter.string(from: date))
            } else {
                throw ConfidenceError.internalError(message: "Could not create date from components")
            }
        case .timestamp(let date):
            let timestampFormatter = ISO8601DateFormatter()
            timestampFormatter.timeZone = TimeZone.init(identifier: "UTC")
            let timestamp = timestampFormatter.string(from: date)
            try container.encode(timestamp)
        case .structure(let structure):
            try container.encode(structure)
        case .list(let list):
            try container.encode(list)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let double = try? container.decode(Double.self) {
            self = .number(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let bool = try? container.decode(Bool.self) {
            self = .boolean(bool)
        } else if let date = try? container.decode(Date.self) {
            self = .timestamp(date)
        } else if let object = try? container.decode(Struct.self) {
            self = .structure(object)
        } else if let list = try? container.decode([StructValue].self) {
            self = .list(list)
        } else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Invalid data"))
        }
    }
}

extension Struct: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(fields)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.fields = try container.decode([String: StructValue].self)
    }
}
