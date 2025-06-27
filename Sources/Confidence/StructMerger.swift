import Foundation

internal enum StructMerger {
    static func mergeStructWithDefault(
        resolved: ConfidenceStruct,
        defaultStruct: ConfidenceStruct
    ) -> ConfidenceStruct {
        var merged = resolved

        // Only replace null values with defaults
        for (key, resolvedValue) in resolved {
            if resolvedValue.isNull(), let defaultValue = defaultStruct[key] {
                merged[key] = defaultValue
            } else if let resolvedNested = resolvedValue.asStructure(),
                let defaultNested = defaultStruct[key]?.asStructure() {
                // Recursively merge nested structs
                merged[key] = ConfidenceValue(
                    structure: mergeStructWithDefault(
                        resolved: resolvedNested,
                        defaultStruct: defaultNested))
            }
        }

        return merged
    }
}
