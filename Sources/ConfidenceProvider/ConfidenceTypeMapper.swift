import Foundation
import Confidence
import OpenFeature

public enum ConfidenceTypeMapper {
    static func from(value: Value) -> ConfidenceValue {
        return convertValue(value)
    }

    static func from(ctx: EvaluationContext?) -> ConfidenceStruct {
        guard let openFeatureContext = ctx else {
            return [:]
        }
        var ofCtxMap = openFeatureContext.asMap()
        // Precendence given to the `attributes` rather then the bespoke `targeting_key`
        if !openFeatureContext.getTargetingKey().isEmpty && !ofCtxMap.keys.contains("targeting_key") {
            ofCtxMap["targeting_key"] = .string(openFeatureContext.getTargetingKey())
        }
        return ofCtxMap.compactMapValues(convertValue)
    }

    // swiftlint:disable:next cyclomatic_complexity
    static private func convertValue(_ value: Value) -> ConfidenceValue {
        switch value {
        case .boolean(let value):
            return ConfidenceValue(boolean: value)
        case .string(let value):
            return ConfidenceValue(string: value)
        case .integer(let value):
            return ConfidenceValue(integer: Int(value))
        case .double(let value):
            return ConfidenceValue(double: value)
        case .date(let value):
            return ConfidenceValue(timestamp: value)
        case .list(let values):
            let types = Set(values.map(convertValue).map { $0.type() })
            guard types.count == 1, let listType = types.first else {
                return ConfidenceValue.init(nullList: [()])
            }
            switch listType {
            case .boolean:
                return ConfidenceValue.init(booleanList: values.compactMap { $0.asBoolean() })
            case .string:
                return ConfidenceValue.init(stringList: values.compactMap { $0.asString() })
            case .integer:
                return ConfidenceValue.init(integerList: values.compactMap { $0.asInteger() }.map { Int($0) })
            case .double:
                return ConfidenceValue.init(doubleList: values.compactMap { $0.asDouble() })
            // Currently Date Value is converted to Timestamp ConfidenceValue to not lose precision, so this should never happen
            case .date:
                let componentsToExtract: Set<Calendar.Component> = [.year, .month, .day]
                return ConfidenceValue.init(dateList: values.compactMap {
                    guard let date = $0.asDate() else {
                        return nil
                    }
                    return Calendar.current.dateComponents(componentsToExtract, from: date)
                })
            case .timestamp:
                return ConfidenceValue.init(timestampList: values.compactMap { $0.asDate() })
            case .list:
                return ConfidenceValue.init(nullList: values.compactMap { _ in () }) // List of list not allowed
            case .structure:
                return ConfidenceValue.init(nullList: values.compactMap { _ in () })  // TODO: List of structures
            case .null:
                return ConfidenceValue.init(nullList: values.compactMap { _ in () })
            }
        case .structure(let values):
            return ConfidenceValue(structure: values.compactMapValues(convertValue))
        case .null:
            return ConfidenceValue(null: ())
        }
    }
}
