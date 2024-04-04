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
            return .boolean(value)
        case .string(let value):
            return .string(value)
        case .integer(let value):
            return .integer(value)
        case .double(let value):
            return .double(value)
        case .date(let value):
            return .timestamp(value)
        case .list(let values):
            return .list(values.compactMap(convertValue))
        case .structure(let values):
            return .structure(values.compactMapValues(convertValue))
        case .null:
            return .null
        }
    }
}
