import Foundation

enum TypeMapper {
    static internal func convert(structure: ConfidenceStruct) -> NetworkStruct {
        return NetworkStruct(fields: structure.compactMapValues(convert))
    }

    static internal func convert(structure: NetworkStruct, schema: StructFlagSchema) throws -> ConfidenceStruct {
        return Dictionary(uniqueKeysWithValues: try structure.fields.map { field, value in
            (field, try convert(value: value, schema: schema.schema[field]))
        })
    }

    // swiftlint:disable:next cyclomatic_complexity
    static func convert(value: ConfidenceValue) -> NetworkValue? {
        switch value.type() {
        case .boolean:
            guard let value = value.asBoolean() else {
                return nil
            }
            return NetworkValue.boolean(value)
        case .string:
            guard let value = value.asString() else {
                return nil
            }
            return NetworkValue.string(value)
        case .integer:
            guard let value = value.asInteger() else {
                return nil
            }
            return NetworkValue.number(Double(value))
        case .double:
            guard let value = value.asDouble() else {
                return nil
            }
            return NetworkValue.number(value)
        case .date:
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.timeZone = TimeZone.current
            dateFormatter.formatOptions = [.withFullDate]
            guard let value = value.asDateComponents(), let dateString = Calendar.current.date(from: value) else {
                return NetworkValue.string("") // This should never happen
            }
            return NetworkValue.string(dateFormatter.string(from: dateString))
        case .timestamp:
            guard let value = value.asDate() else {
                return nil
            }
            let timestampFormatter = ISO8601DateFormatter()
            timestampFormatter.timeZone = TimeZone.init(identifier: "UTC")
            let timestamp = timestampFormatter.string(from: value)
            return NetworkValue.string(timestamp)
        case .list:
            guard let value = value.asList() else {
                return nil
            }
            return NetworkValue.list(value.compactMap(convert))
        case .structure:
            guard let value = value.asStructure() else {
                return nil
            }
            return NetworkValue.structure(NetworkStruct(fields: value.compactMapValues(convert)))
        case .null:
            return .null
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    static private func convert(value: NetworkValue, schema: FlagSchema?) throws -> ConfidenceValue {
        guard let fieldType = schema else {
            throw ConfidenceError.parseError(message: "Mismatch between schema and value")
        }

        switch value {
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
                    return (field, try convert(value: fieldValue, schema: structSchema.schema[field]))
                }))
        case .list(let values):
            guard case .listSchema(let listSchema) = fieldType else {
                throw ConfidenceError.parseError(message: "Field is list in schema but something else in value")
            }
            return ConfidenceValue.init(list: try values.map { fieldValue in
                try convert(value: fieldValue, schema: listSchema)
            })
        }
    }
}
