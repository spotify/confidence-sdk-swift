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
            return nil
        case .timestamp:
            return nil
        case .list:
            return nil
        case .structure:
            return nil
        case .null:
            return nil
        }
    }
}
