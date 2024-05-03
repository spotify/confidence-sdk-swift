import Foundation
import Common

public enum TypeMapper {
    static func from(value: ConfidenceStruct) -> NetworkStruct {
        return NetworkStruct(fields: value.compactMapValues(convertValueToStructValue))
    }

    static func from(value: ConfidenceValue) throws -> NetworkStruct {
        guard let value = value.asStructure() else {
            throw ConfidenceError.parseError(message: "Value must be a .structure")
        }

        return NetworkStruct(fields: value.compactMapValues(convertValueToStructValue))
    }

    static func from(
        object: NetworkStruct, schema: StructFlagSchema
    )
    throws
    -> ConfidenceValue
    {
        let structure = Dictionary(uniqueKeysWithValues: try object.fields.map { field, value in
            (field, try convertStructValueToValue(value, schema: schema.schema[field]))
        })
        return .init(structure: structure)
    }

    static private func convertValueToStructValue(_ value: ConfidenceValue) -> NetworkValue? {
        if let value = value.asBoolean() {
            return .boolean(value)
        } else if let value = value.asInteger() {
            return .number(Double(value))
        } else if let value = value.asDate() {
            let timestampFormatter = ISO8601DateFormatter()
            timestampFormatter.timeZone = TimeZone.init(identifier: "UTC")
            let timestamp = timestampFormatter.string(from: value)
            return .string(timestamp)
        } else if let value = value.asDouble() {
            return .number(value)
        } else if let value = value.asString() {
            return .string(value)
        } else if let value = value.asList()  {
            return .list(value.compactMap(convertValueToStructValue))
        } else if let value = value.asStructure()  {
            return .structure(NetworkStruct(fields: value.compactMapValues(convertValueToStructValue)))
        } else {
            return NetworkValue.null
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    static private func convertStructValueToValue(
        _ structValue: NetworkValue, schema: FlagSchema?
    ) throws -> ConfidenceValue {
        guard let fieldType = schema else {
            throw ConfidenceError.parseError(message: "Mismatch between schema and value")
        }

        switch structValue {
        case .null:
            return .init(null: ())
        case .number(let value):
            switch fieldType {
            case .intSchema:
                return .init(integer: Int(value))
            case .doubleSchema:
                return .init(double: value)
            default:
                throw ConfidenceError.parseError(message: "Number field must have schema type int or double")
            }
        case .string(let value):
            return .init(string: value)
        case .boolean(let value):
            return .init(boolean: value)
        case .structure(let mapValue):
            guard case .structSchema(let structSchema) = fieldType else {
                throw ConfidenceError.parseError(message: "Field is struct in schema but something else in value")
            }
            return .init(structure: Dictionary(
                uniqueKeysWithValues: try mapValue.fields.map { field, fieldValue in
                    return (field, try convertStructValueToValue(fieldValue, schema: structSchema.schema[field]))
                }))
        case .list(let values):
            guard case .listSchema(let listSchema) = fieldType else {
                throw ConfidenceError.parseError(message: "Field is list in schema but something else in value")
            }
            return ConfidenceValue.init(list: try values.map { fieldValue in
                try convertStructValueToValue(fieldValue, schema: listSchema)
            })
        }
    }
}
