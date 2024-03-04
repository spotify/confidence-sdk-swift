import Foundation
import OpenFeature
import XCTest

@testable import Confidence

class DefaultStorageTest: XCTestCase {
    var storage = DefaultStorage(filePath: "resolver.cache")

    override func setUp() {
        super.setUp()
        try? storage.clear()
    }

    func testGetConfigUrl() throws {
        let url = try storage.getConfigUrl()

        let numComponents = url.pathComponents.count

        XCTAssertEqual(url.pathComponents[numComponents - 1], "resolver.cache")
        XCTAssertEqual(url.pathComponents[numComponents - 3], "com.confidence.cache")
        XCTAssertEqual(url.pathComponents[numComponents - 4], "Application Support")
    }

    func testSaveConfig() throws {
        let value: Value = .structure([
            "int": .integer(3),
            "string": .string("test"),
        ])

        try storage.save(data: value)

        let restoredValue: Value = try storage.load(defaultValue: .null)

        XCTAssertEqual(restoredValue, value)
    }

    func testLoadNonExistingFileReturnsDefault() throws {
        let url = try storage.getConfigUrl()
        if FileManager.default.fileExists(atPath: url.backport.path) {
            try FileManager.default.removeItem(atPath: url.backport.path)
        }

        let value: Value = try storage.load(defaultValue: .integer(3))

        XCTAssertEqual(value, Value.integer(3))
    }

    func testSupportMultipleFiles() throws {
        // Given non empty resolve storage
        let cacheStorage = storage
        let value: Value = .structure([
            "int": .integer(3),
            "string": .string("test"),
        ])
        try cacheStorage.save(data: value)

        // When apply storage is initialised with different file path
        let applyStorage = DefaultStorage(filePath: "resolver.apply")
        let cacheData = CacheData(resolveToken: "token", flagName: "name", applyTime: Date())
        try applyStorage.save(data: cacheData)

        // Then it does not override any of the files
        let readCacheValue: Value = try cacheStorage.load(defaultValue: .integer(3))
        let readApplyValue: CacheData = try applyStorage.load(defaultValue: CacheData.empty())
        XCTAssertEqual(readCacheValue, value)
        XCTAssertEqual(readApplyValue.resolveEvents.first?.resolveToken, "token")
        XCTAssertEqual(readApplyValue.resolveEvents.first?.events.first?.name, "name")
    }

    func testClearStorage() throws {
        // Given non empty storage
        let value: Value = .structure([
            "int": .integer(3),
            "string": .string("test"),
        ])
        try storage.save(data: value)

        // When clear storage is called
        try storage.clear()

        // Then storage return default value on read
        let readValue: Value = try storage.load(defaultValue: Value.null)
        XCTAssertEqual(readValue, Value.null)
    }
}
