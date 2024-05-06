import Foundation

public enum NetworkTypeMapper {
    public static func from(value: ConfidenceStruct) throws -> NetworkStruct {
        NetworkStruct(fields: try value.compactMapValues(convertValue))
    }

    // swiftlint:disable:next cyclomatic_complexity
    public static func convertValue(_ value: ConfidenceValue) throws -> NetworkValue? {
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
                throw ConfidenceError.internalError(message: "Could not create date from components")
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
            return try NetworkValue.list(value.compactMap(convertValue))
        case .structure:
            guard let value = value.asStructure() else {
                return nil
            }
            return try NetworkValue.structure(NetworkStruct(fields: value.compactMapValues(convertValue)))
        case .null:
            return nil
        }
    }
}
