import Foundation

internal protocol PayloadMerger {
    func merge(context: ConfidenceStruct, data: ConfidenceStruct) throws -> ConfidenceStruct
}

internal struct PayloadMergerImpl: PayloadMerger {
    func merge(context: ConfidenceStruct, data: ConfidenceStruct) throws -> ConfidenceStruct {
        guard data["context"] == nil else {
            throw ConfidenceError.invalidContextInMessage
        }
        var map: ConfidenceStruct = data
        map["context"] = ConfidenceValue.init(structure: context)
        return map
    }
}

extension Dictionary {
    static func += (lhs: inout Self, rhs: Self) {
        lhs.merge(rhs) { _, new in new }
    }
}
