import Foundation
import OpenFeature
import XCTest

@testable import ConfidenceProvider

class StorageMock: Storage {
    var data = ""

    var saveExpectation: XCTestExpectation?

    convenience init(data: Encodable) throws {
        self.init()
        try self.save(data: data)
    }

    func save(data: Encodable) throws {
        let dataB = try JSONEncoder().encode(data)
        self.data = String(data: dataB, encoding: .utf8) ?? ""

        saveExpectation?.fulfill()
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
