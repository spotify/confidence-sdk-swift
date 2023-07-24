import Foundation
import OpenFeature

public enum TypeMapper {
    static func from(value: Structure) -> Struct {
        return Struct(fields: value.asMap().compactMapValues(convertValueToStructValue))
    }

    static func from(value: Value) throws -> Struct {
        guard case .structure(let values) = value else {
            throw OpenFeatureError.parseError(message: "Value must be a .structure")
        }

        return Struct(fields: values.compactMapValues(convertValueToStructValue))
    }

    static func from(
        object: Struct, schema: StructFlagSchema
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

    static private func convertValueToStructValue(_ value: Value) -> StructValue? {
        switch value {
        case .boolean(let value):
            return StructValue.bool(value)
        case .string(let value):
            return StructValue.string(value)
        case .integer(let value):
            return StructValue.number(Double(value))
        case .double(let value):
            return StructValue.number(value)
        case .date(let value):
            return StructValue.date(value)
        case .list(let values):
            return .list(values.compactMap(convertValueToStructValue))
        case .structure(let values):
            return .object(Struct(fields: values.compactMapValues(convertValueToStructValue)))
        case .null:
            return StructValue.null
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    static private func convertStructValueToValue(
        _ structValue: StructValue, schema: FlagSchema?
    ) throws -> Value {
        guard let fieldType = schema else {
            throw OpenFeatureError.parseError(message: "Mismatch between schema and value")
        }

        switch structValue {
        case .null:
            return .null
        case .number(let value):
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
        case .bool(let value):
            return .boolean(value)
        case .date(let value):
            return .date(value)
        case .object(let mapValue):
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
        }
    }
}
