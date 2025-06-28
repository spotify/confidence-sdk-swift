import Foundation

internal enum StructMerger {
    static func mergeStructWithDefault(
        resolved: ConfidenceStruct,
        defaultStruct: ConfidenceStruct
    ) -> ConfidenceStruct {
        var merged = resolved
        for (key, resolvedValue) in resolved {
            if resolvedValue.isNull(), let defaultValue = defaultStruct[key] {
                merged[key] = defaultValue
            } else if let resolvedNested = resolvedValue.asStructure(),
                let defaultNested = defaultStruct[key]?.asStructure() {
                merged[key] = ConfidenceValue(
                    structure: mergeStructWithDefault(
                        resolved: resolvedNested,
                        defaultStruct: defaultNested))
            }
        }

        return merged
    }

    static func mergeDictionaryWithDefault(
        resolved: ConfidenceStruct,
        defaultDict: [String: Any]
    ) -> [String: Any] {
        var merged: [String: Any] = [:]
        for (key, resolvedValue) in resolved {
            if resolvedValue.isNull(), let defaultValue = defaultDict[key] {
                merged[key] = defaultValue
            } else if resolvedValue.type() == .structure,
                let resolvedNested = resolvedValue.asStructure(),
                let defaultNested = defaultDict[key] as? [String: Any] {
                merged[key] = mergeDictionaryWithDefault(
                    resolved: resolvedNested,
                    defaultDict: defaultNested
                )
            } else {
                merged[key] = resolvedValue.asNative()
            }
        }
        return merged
    }
}
