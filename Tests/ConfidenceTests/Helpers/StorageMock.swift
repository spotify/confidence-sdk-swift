import Foundation
import OpenFeature
import XCTest

@testable import Confidence

class StorageMock: Storage {
    var data = ""
    var saveExpectation: XCTestExpectation?
    private let storageQueue = DispatchQueue(label: "com.confidence.storagemock")

    convenience init(data: Encodable) throws {
        self.init()
        try self.save(data: data)
    }

    func save(data: Encodable) throws {
        try storageQueue.sync {
            let dataB = try JSONEncoder().encode(data)
            self.data = String(decoding: dataB, as: UTF8.self)

            saveExpectation?.fulfill()
        }
    }

    func load<T>(defaultValue: T) throws -> T where T: Decodable {
        try storageQueue.sync {
            if data.isEmpty {
                return defaultValue
            }
            return try JSONDecoder().decode(T.self, from: try XCTUnwrap(data.data(using: .utf8)))
        }
    }

    func clear() throws {
        storageQueue.sync {
            data = ""
        }
    }

    func isEmpty() -> Bool {
        storageQueue.sync {
            return data.isEmpty
        }
    }
}
