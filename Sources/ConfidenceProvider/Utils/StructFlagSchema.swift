import Foundation

struct StructFlagSchema: Equatable, Codable {
    var schema: [String: FlagSchema]
}

indirect enum FlagSchema: Equatable, Codable {
    case structSchema(StructFlagSchema)
    case listSchema(FlagSchema)
    case intSchema
    case doubleSchema
    case stringSchema
    case boolSchema
}
