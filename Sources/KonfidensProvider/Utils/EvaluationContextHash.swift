import CryptoKit
import Foundation
import OpenFeature

extension EvaluationContext {
    func hash() -> String {
        hashEvaluationContext(context: self)
    }
}

func hashEvaluationContext(context: EvaluationContext) -> String {
    var hasher = SHA256()

    hasher.update(data: context.getTargetingKey().data)
    context.asMap().sorted { $0.key < $1.key }.forEach { key, value in
        hasher.update(data: key.data)
        hashValue(value: value, hasher: &hasher)
    }

    let digest = hasher.finalize()

    return digest.map { String(format: "%02hhx", $0) }.joined()
}

func hashValue(value: Value, hasher: inout some HashFunction) {
    switch value {
    case .boolean(let bool):
        hasher.update(data: bool.data)
    case .string(let string):
        hasher.update(data: string.data)
    case .integer(let int64):
        hasher.update(data: int64.data)
    case .double(let double):
        hasher.update(data: double.data)
    case .date(let date):
        hasher.update(data: date.data)
    case .list(let list):
        list.forEach { listValue in
            hashValue(value: listValue, hasher: &hasher)
        }
    case .structure(let structure):
        structure.sorted { $0.key < $1.key }.forEach { key, structureValue in
            hasher.update(data: key.data)
            hashValue(value: structureValue, hasher: &hasher)
        }
    case .null:
        hasher.update(data: UInt8(0).data)
    }
}

extension StringProtocol {
    var data: Data { .init(utf8) }
}

extension Numeric {
    var data: Data {
        var source = self
        return .init(bytes: &source, count: MemoryLayout<Self>.size)
    }
}

extension Bool {
    var data: Data { UInt8(self ? 1 : 0).data }
}

extension Date {
    var data: Data {
        self.timeIntervalSince1970.data
    }
}
