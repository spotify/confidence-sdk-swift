import Foundation
import Confidence
import OpenFeature

public enum ConfidenceTypeMapper {
    static func from(value: Value) -> ConfidenceValue {
        return convertValue(value)
    }

    static func from(ctx: EvaluationContext) -> ConfidenceStruct {
        var ctxMap = ctx.asMap()
        ctxMap["targeting_key"] = .string(ctx.getTargetingKey())
        return ctxMap.compactMapValues(convertValue)
    }

    static private func convertValue(_ value: Value) -> ConfidenceValue {
        switch value {
        case .boolean(let value):
            return ConfidenceValue(boolean: value)
        case .string(let value):
            return ConfidenceValue(string: value)
        case .integer(let value):
            return ConfidenceValue(integer: value)
        case .double(let value):
            return ConfidenceValue(double: value)
        case .date(let value):
            return ConfidenceValue(timestamp: value)
        case .list(let values):
            return ConfidenceValue(list: values.compactMap(convertValue))
        case .structure(let values):
            return ConfidenceValue(structure: values.compactMapValues(convertValue))
        case .null:
            return ConfidenceValue(null: ())
        }
    }
}
