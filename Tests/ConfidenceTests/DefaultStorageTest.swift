import Foundation
import Common
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
        let value = ConfidenceValue(structure: [
            "int": ConfidenceValue(integer: 3),
            "string": ConfidenceValue(string: "test"),
        ])

        try storage.save(data: value)

        let restoredValue: ConfidenceValue = try storage.load(defaultValue: .init(structure: [:]))

        XCTAssertEqual(restoredValue, value)
    }

    func testLoadNonExistingFileReturnsDefault() throws {
        let url = try storage.getConfigUrl()
        if FileManager.default.fileExists(atPath: url.backport.path) {
            try FileManager.default.removeItem(atPath: url.backport.path)
        }

        let value: ConfidenceValue = try storage.load(defaultValue: .init(integer: 3))

        XCTAssertEqual(value, ConfidenceValue(integer: 3))
    }

    func testSupportMultipleFiles() throws {
        // Given non empty resolve storage
        let cacheStorage = storage
        let value = ConfidenceValue(structure: [
            "int": .init(integer: 3),
            "string": .init(string: "test"),
        ])
        try cacheStorage.save(data: value)

        // When apply storage is initialised with different file path
        let applyStorage = DefaultStorage(filePath: "resolver.apply")
        let cacheData = CacheData(resolveToken: "token", flagName: "name", applyTime: Date())
        try applyStorage.save(data: cacheData)

        // Then it does not override any of the files
        let readCacheValue: ConfidenceValue = try cacheStorage.load(defaultValue: .init(integer: 3))
        let readApplyValue: CacheData = try applyStorage.load(defaultValue: CacheData.empty())
        XCTAssertEqual(readCacheValue, value)
        XCTAssertEqual(readApplyValue.resolveEvents.first?.resolveToken, "token")
        XCTAssertEqual(readApplyValue.resolveEvents.first?.events.first?.name, "name")
    }

    func testClearStorage() throws {
        // Given non empty storage
        let value: ConfidenceValue = .init(structure: [
            "int": .init(integer: 3),
            "string": .init(string: "test"),
        ])
        try storage.save(data: value)

        // When clear storage is called
        try storage.clear()

        // Then storage return default value on read
        let readValue: ConfidenceValue = try storage.load(defaultValue: ConfidenceValue.init(null: ()))
        XCTAssertEqual(readValue, .init(null: ()))
    }
}
