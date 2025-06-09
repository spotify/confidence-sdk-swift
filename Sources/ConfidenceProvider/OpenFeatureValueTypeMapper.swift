import OpenFeature
import Foundation

extension OpenFeature.Value {
    public func asNativeDictionary() -> [String: Any]? {
        guard case let .structure(valueMap) = self else {
            return nil
        }

        return valueMap.mapValues { value in
            return value.asNativeType()
        }
    }

    public func asNativeType() -> Any {
        switch self {
        case .boolean(let value):
            return value
        case .string(let value):
            return value
        case .integer(let value):
            return value
        case .double(let value):
            return value
        case .date(let value):
            return value
        case .list(let values):
            return values.map { $0.asNativeType() }
        case .structure(let valueMap):
            return valueMap.mapValues { $0.asNativeType() }
        case .null:
            return NSNull()
        }
    }

    public static func fromNativeDictionary(_ dictionary: [String: Any]) throws -> OpenFeature.Value {
        let convertedMap = try dictionary.mapValues { value in
            return try fromNativeType(value)
        }
        return .structure(convertedMap)
    }

    public static func fromNativeType(_ value: Any) throws -> OpenFeature.Value {
        // Handle numeric types first
        if let boolValue = value as? Bool {
            return .boolean(boolValue)
        }
        if let stringValue = value as? String {
            return .string(stringValue)
        }

        // Handle integer types
        if let intValue = value as? Int {
            return .integer(Int64(intValue))
        }
        if let int64Value = value as? Int64 {
            return .integer(int64Value)
        }
        if let int32Value = value as? Int32 {
            return .integer(Int64(int32Value))
        }

        if let doubleValue = value as? Double {
            return .double(doubleValue)
        }
        if let floatValue = value as? Float {
            return .double(Double(floatValue))
        }

        return try handleOtherNativeTypes(value)
    }

    private static func handleOtherNativeTypes(_ value: Any) throws -> OpenFeature.Value {
        if let dateValue = value as? Date {
            return .date(dateValue)
        }
        if let arrayValue = value as? [Any] {
            let convertedArray = try arrayValue.map { try fromNativeType($0) }
            return .list(convertedArray)
        }
        if let dictValue = value as? [String: Any] {
            let convertedDict = try dictValue.mapValues { try fromNativeType($0) }
            return .structure(convertedDict)
        }
        if value is NSNull {
            return .null
        }
        throw OpenFeatureError.parseError(
            message: "Unexpected type from provider: \(String(describing: type(of: value)))")
    }
}
