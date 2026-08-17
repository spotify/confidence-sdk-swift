import Foundation

internal protocol PayloadMerger {
    func merge(context: ConfidenceStruct, data: ConfidenceStruct) throws -> ConfidenceStruct
}

internal struct PayloadMergerImpl: PayloadMerger {
    func merge(context: ConfidenceStruct, data: ConfidenceStruct) throws -> ConfidenceStruct {
        var map: ConfidenceStruct = data
        if let contextFromData = data["context"] {
            // An explicit "context" entry in event data overrides the evaluation context for this event.
            map["context"] = contextFromData
        } else {
            map["context"] = ConfidenceValue.init(structure: context)
        }
        return map
    }
}

extension Dictionary {
    static func += (lhs: inout Self, rhs: Self) {
        lhs.merge(rhs) { _, new in new }
    }
}
