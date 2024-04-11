import Foundation
import Common
import OpenFeature

public enum TypeMapper {
    static func from(value: Structure) -> NetworkStruct {
        return NetworkStruct(fields: value.asMap().compactMapValues(convertValueToStructValue))
    }

    static func from(value: Value) throws -> NetworkStruct {
        guard case .structure(let values) = value else {
            throw OpenFeatureError.parseError(message: "Value must be a .structure")
        }

        return NetworkStruct(fields: values.compactMapValues(convertValueToStructValue))
    }

    static func from(
        object: NetworkStruct, schema: StructFlagSchema
    )
        throws
        -> Value
    {
        return .structure(
            Dictionary(
                uniqueKeysWithValues: try object.fields.map { field, value in
                    (field, try convertStructValueToValue(value, schema: schema.schema[field]))
                }))
    }

    static private func convertValueToStructValue(_ value: Value) -> NetworkStructValue? {
        switch value {
        case .boolean(let value):
            return NetworkStructValue.boolean(value)
        case .string(let value):
            return NetworkStructValue.string(value)
        case .integer(let value):
            return NetworkStructValue.integer(value)
        case .double(let value):
            return NetworkStructValue.double(value)
        case .date(let value):
            return NetworkStructValue.timestamp(value)
        case .list(let values):
            return .list(values.compactMap(convertValueToStructValue))
        case .structure(let values):
            return .structure(NetworkStruct(fields: values.compactMapValues(convertValueToStructValue)))
        case .null:
            return NetworkStructValue.null
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    static private func convertStructValueToValue(
        _ structValue: NetworkStructValue, schema: FlagSchema?
    ) throws -> Value {
        guard let fieldType = schema else {
            throw OpenFeatureError.parseError(message: "Mismatch between schema and value")
        }

        switch structValue {
        case .null:
            return .null
        case .integer(let value):
            return .integer(value)
        case .double(let value):
            switch fieldType {
            case .intSchema:
                return .integer(Int64(value))
            case .doubleSchema:
                return .double(value)
            default:
                throw OpenFeatureError.parseError(message: "Number field must have schema type int or double")
            }
        case .string(let value):
            return .string(value)
        case .boolean(let value):
            return .boolean(value)
        case .date(let value):
            guard let timestamp = Calendar.current.date(from: value) else {
                throw OpenFeatureError.parseError(message: "Error converting date data")
            }
            return .date(timestamp)
        case .structure(let mapValue):
            guard case .structSchema(let structSchema) = fieldType else {
                throw OpenFeatureError.parseError(message: "Field is struct in schema but something else in value")
            }

            return .structure(
                Dictionary(
                    uniqueKeysWithValues: try mapValue.fields.map { field, fieldValue in
                        return (field, try convertStructValueToValue(fieldValue, schema: structSchema.schema[field]))
                    }))
        case .list(let listValue):
            guard case .listSchema(let listSchema) = fieldType else {
                throw OpenFeatureError.parseError(message: "Field is list in schema but something else in value")
            }

            return .list(
                try listValue.map { fieldValue in
                    try convertStructValueToValue(fieldValue, schema: listSchema)
                }
            )
        case .integer(let value):
            return .integer(value)
        case .double(let value):
            return .double(value)
        case .timestamp(let value):
            return .date(value)
        }
    }
}
