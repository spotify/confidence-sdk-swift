import Foundation

struct Struct: Equatable {
    var fields: [String: StructValue]
}

enum StructValue: Equatable {
    case null
    case number(Double)
    case string(String)
    case bool(Bool)
    case date(Date)
    case object(Struct)
    case list([StructValue])
}

extension StructValue: Codable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null:
            try container.encodeNil()
        case .number(let double):
            try container.encode(double)
        case .string(let string):
            try container.encode(string)
        case .bool(let bool):
            try container.encode(bool)
        case .date(let date):
            try container.encode(date)
        case .object(let object):
            try container.encode(object)
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
            self = .bool(bool)
        } else if let date = try? container.decode(Date.self) {
            self = .date(date)
        } else if let object = try? container.decode(Struct.self) {
            self = .object(object)
        } else if let list = try? container.decode([StructValue].self) {
            self = .list(list)
        } else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Invalid data"))
        }
    }
}

extension Struct: Codable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(fields)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.fields = try container.decode([String: StructValue].self)
    }
}
