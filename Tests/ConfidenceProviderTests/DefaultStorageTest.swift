import Foundation
import OpenFeature
import XCTest

@testable import ConfidenceProvider

class DefaultStorageTest: XCTestCase {
    func testGetConfigUrl() throws {
        let url = try DefaultStorage.getConfigUrl()

        let numComponents = url.pathComponents.count

        XCTAssertEqual(url.pathComponents[numComponents - 1], "resolver.cache")
        XCTAssertEqual(url.pathComponents[numComponents - 3], "com.confidence.cache")
        XCTAssertEqual(url.pathComponents[numComponents - 4], "Application Support")
    }

    func testSaveConfig() throws {
        let storage = DefaultStorage()

        let value: Value = .structure([
            "int": .integer(3),
            "string": .string("test"),
        ])

        try storage.save(data: value)

        let restoredValue = try storage.load(Value.self, defaultValue: .null)

        XCTAssertEqual(restoredValue, value)
    }

    func testLoadNonExistingFileReturnsDefault() throws {
        let url = try DefaultStorage.getConfigUrl()
        if FileManager.default.fileExists(atPath: url.backport.path) {
            try FileManager.default.removeItem(atPath: url.backport.path)
        }

        let storage = DefaultStorage()
        let value = try storage.load(Value.self, defaultValue: .integer(3))

        XCTAssertEqual(value, Value.integer(3))
    }
}
