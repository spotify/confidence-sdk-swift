import Foundation

internal protocol PayloadMerger {
    func merge(context: ConfidenceStruct, message: ConfidenceStruct) -> ConfidenceStruct
}

internal struct PayloadMergerImpl: PayloadMerger {
    func merge(context: ConfidenceStruct, message: ConfidenceStruct) -> ConfidenceStruct {
        var map: ConfidenceStruct = context
        map += message
        return map
    }
}

extension Dictionary {
    static func += (lhs: inout Self, rhs: Self) {
        lhs.merge(rhs) { _, new in new }
    }
}
