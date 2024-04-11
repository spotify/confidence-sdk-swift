import Foundation
import Common

public enum NetworkTypeMapper {
    public static func from(value: ConfidenceStruct) -> NetworkStruct {
        NetworkStruct(fields: value.compactMapValues(convertValue))
    }

    // swiftlint:disable:next cyclomatic_complexity
    public static func convertValue(_ value: ConfidenceValue) -> NetworkStructValue? {
        switch value.type() {
        case .boolean:
            guard let value = value.asBoolean() else {
                return nil
            }
            return NetworkStructValue.boolean(value)
        case .string:
            guard let value = value.asString() else {
                return nil
            }
            return NetworkStructValue.string(value)
        case .integer:
            guard let value = value.asInteger() else {
                return nil
            }
            return NetworkStructValue.number(Double(value))
        case .double:
            guard let value = value.asDouble() else {
                return nil
            }
            return NetworkStructValue.number(value)
        case .date:
            guard let value = value.asDateComponents() else {
                return nil
            }
            return NetworkStructValue.date(value)
        case .timestamp:
            guard let value = value.asDate() else {
                return nil
            }
            return NetworkStructValue.timestamp(value)
        case .list:
            guard let value = value.asList() else {
                return nil
            }
            return NetworkStructValue.list(value.compactMap(convertValue))
        case .structure:
            guard let value = value.asStructure() else {
                return nil
            }
            return NetworkStructValue.structure(NetworkStruct(fields: value.compactMapValues(convertValue)))
        case .null:
            return nil
        }
    }
}
