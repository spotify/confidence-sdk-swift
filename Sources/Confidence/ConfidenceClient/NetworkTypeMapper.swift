import Foundation
import Common

public enum NetworkTypeMapper {
    public static func from(value: ConfidenceStruct) -> Struct {
        Struct(fields: value.compactMapValues(convertValue))
    }

    // swiftlint:disable:next cyclomatic_complexity
    public static func convertValue(_ value: ConfidenceValue) -> StructValue? {
        switch value.type() {
        case .boolean:
            guard let value = value.asBoolean() else {
                return nil
            }
            return StructValue.boolean(value)
        case .string:
            guard let value = value.asString() else {
                return nil
            }
            return StructValue.string(value)
        case .integer:
            guard let value = value.asInteger() else {
                return nil
            }
            return StructValue.number(Double(value))
        case .double:
            guard let value = value.asDouble() else {
                return nil
            }
            return StructValue.number(value)
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
