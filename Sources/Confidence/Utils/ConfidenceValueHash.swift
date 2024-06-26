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

// swiftlint:disable:next cyclomatic_complexity
func hashValue(value: ConfidenceValue, hasher: inout some HashFunction) {
    switch value.type() {
    case .boolean:
        if let booleanData = value.asBoolean()?.data {
            hasher.update(data: booleanData)
        }

    case .string:
        if let stringData = value.asString()?.data {
            hasher.update(data: stringData)
        }

    case .integer:
        if let integerData = value.asInteger()?.data {
            hasher.update(data: integerData)
        }

    case .double:
        if let doubleData = value.asDouble()?.data {
            hasher.update(data: doubleData)
        }

    case .date:
        if let dateData = value.asDateComponents()?.date?.data {
            hasher.update(data: dateData)
        }

    case .list:
        value.asList()?.forEach { listValue in
            hashValue(value: listValue, hasher: &hasher)
        }

    case .timestamp:
        if let timestampData = value.asDate()?.data {
            hasher.update(data: timestampData)
        }

    case .structure:
        value.asStructure()?.sorted { $0.key < $1.key }.forEach { key, structureValue in
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
