import Foundation

struct StructFlagSchema: Equatable {
    var schema: [String: FlagSchema]

    enum CodingKeys: String, CodingKey {
        case schema
    }
}

indirect enum FlagSchema: Equatable {
    case structSchema(StructFlagSchema)
    case listSchema(FlagSchema)
    case intSchema
    case doubleSchema
    case stringSchema
    case boolSchema

    enum CodingKeys: String, CodingKey {
        case structSchema
        case listSchema
        case intSchema
        case doubleSchema
        case stringSchema
        case boolSchema
    }
}

extension FlagSchema: Codable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        let empty: [String: String] = [:]
        switch self {
        case .structSchema(let structSchema):
            try container.encode(structSchema, forKey: .structSchema)
        case .listSchema(let elementSchema):
            try container.encode(elementSchema, forKey: .listSchema)
        case .intSchema:
            try container.encode(empty, forKey: .intSchema)
        case .doubleSchema:
            try container.encode(empty, forKey: .doubleSchema)
        case .stringSchema:
            try container.encode(empty, forKey: .stringSchema)
        case .boolSchema:
            try container.encode(empty, forKey: .boolSchema)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if container.contains(.structSchema) {
            let structSchema = try container.decode(StructFlagSchema.self, forKey: .structSchema)
            self = .structSchema(structSchema)
        } else if container.contains(.listSchema) {
            let elementSchema = try container.decode(FlagSchema.self, forKey: .listSchema)
            self = .listSchema(elementSchema)
        } else if container.contains(.intSchema) {
            self = .intSchema
        } else if container.contains(.doubleSchema) {
            self = .doubleSchema
        } else if container.contains(.stringSchema) {
            self = .stringSchema
        } else if container.contains(.boolSchema) {
            self = .boolSchema
        } else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Invalid data"))
        }
    }
}

extension StructFlagSchema: Codable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(schema, forKey: .schema)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.schema = try container.decode([String: FlagSchema].self, forKey: .schema)
    }
}
