import CryptoKit
import Foundation

public extension ConfidenceStruct {
    func hash() -> String {
        hashConfidenceValue(context: self)
    }
}

func hashConfidenceValue(context: ConfidenceStruct) -> String {
    var hasher = SHA256()

    context.sorted { $0.key < $1.key }.forEach { key, value in
        hasher.update(data: key.data)
        hashValue(value: value, hasher: &hasher)
    }

    let digest = hasher.finalize()

    return digest.map { String(format: "%02hhx", $0) }.joined()
}

func hashValue(value: ConfidenceValue, hasher: inout some HashFunction) {
    switch value.type() {
    case .boolean:
        hasher.update(data: value.asBoolean()!.data)
    case .string:
        hasher.update(data: value.asString()!.data)
    case .integer:
        hasher.update(data: value.asInteger()!.data)
    case .double:
        hasher.update(data: value.asDouble()!.data)
    case .date:
        hasher.update(data: value.asDate()!.data)
    case .list:
        value.asList()!.forEach { listValue in
            hashValue(value: listValue, hasher: &hasher)
        }
    case .timestamp:
        hasher.update(data: value.asDateComponents()!.date!.data)
    case .structure:
        value.asStructure()!.sorted { $0.key < $1.key }.forEach { key, structureValue in
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
