import Foundation

internal protocol PayloadMerger {
    func merge(context: ConfidenceStruct, message: ConfidenceStruct) -> ConfidenceStruct
}

internal struct PayloadMergerImpl: PayloadMerger {
    func merge(context: ConfidenceStruct, message: ConfidenceStruct) -> ConfidenceStruct {
        let messageContextStruct = message["context"]?.asStructure() ?? [:]
        var mutableContext = context
        messageContextStruct.forEach { entry in
            mutableContext.updateValue(entry.value, forKey: entry.key)
        }
        var mutablePayload = message
        mutablePayload["context"] = .init(structure: mutableContext)
        return mutablePayload
    }
}

extension Dictionary {
    static func += (lhs: inout Self, rhs: Self) {
        lhs.merge(rhs) { _, new in new }
    }
}
