import Foundation
import OpenFeature

@testable import ConfidenceProvider

class StorageMock: Storage {
    var data = ""

    func save(data: Encodable) throws {
        let dataB = try JSONEncoder().encode(data)
        self.data = String(data: dataB, encoding: .utf8) ?? ""
    }

    func load<T>(defaultValue: T) throws -> T where T: Decodable {
        if data.isEmpty {
            return defaultValue
        }
        return try JSONDecoder().decode(T.self, from: data.data)
    }

    func clear() throws {
        data = ""
    }
}
