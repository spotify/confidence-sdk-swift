import Foundation
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

    func testResolvedValueShouldApplyBackwardCompatibility() throws {
        struct LegacyResolvedValue: Codable, Equatable {
            var variant: String?
            var value: ConfidenceValue?
            var flag: String
            var resolveReason: ResolveReason
            // Note: shouldApply field is intentionally missing to simulate old data
        }

        struct LegacyFlagResolution: Codable, Equatable {
            let context: ConfidenceStruct
            let flags: [LegacyResolvedValue]
            let resolveToken: String
        }

        let legacyResolvedValue = LegacyResolvedValue(
            variant: "control",
            value: .init(structure: ["size": .init(integer: 42)]),
            flag: "test_flag",
            resolveReason: .match
        )

        let legacyResolution = LegacyFlagResolution(
            context: ["targeting_key": .init(string: "user1")],
            flags: [legacyResolvedValue],
            resolveToken: "legacy_token"
        )

        try storage.save(data: legacyResolution)
        let restoredResolution: FlagResolution = try storage.load(defaultValue: FlagResolution.EMPTY)

        XCTAssertEqual(restoredResolution.flags.count, 1)
        let restoredFlag = restoredResolution.flags[0]
        XCTAssertEqual(restoredFlag.flag, "test_flag")
        XCTAssertEqual(restoredFlag.variant, "control")
        XCTAssertEqual(restoredFlag.resolveReason, .match)
        XCTAssertTrue(restoredFlag.shouldApply, "shouldApply should default to true for backward compatibility")
        XCTAssertEqual(restoredFlag.value?.asStructure()?["size"]?.asInteger(), 42)
    }

    func testResolvedValueShouldApplyExplicitValue() throws {
        let resolvedValue = ResolvedValue(
            variant: "control",
            value: .init(structure: ["size": .init(integer: 42)]),
            flag: "test_flag",
            resolveReason: .match,
            shouldApply: false  // Explicitly set to false
        )

        let resolution = FlagResolution(
            context: ["targeting_key": .init(string: "user1")],
            flags: [resolvedValue],
            resolveToken: "test_token"
        )

        try storage.save(data: resolution)

        let restoredResolution: FlagResolution = try storage.load(defaultValue: FlagResolution.EMPTY)

        XCTAssertEqual(restoredResolution.flags.count, 1)
        let restoredFlag = restoredResolution.flags[0]
        XCTAssertEqual(restoredFlag.flag, "test_flag")
        XCTAssertEqual(restoredFlag.variant, "control")
        XCTAssertEqual(restoredFlag.resolveReason, .match)
        XCTAssertFalse(restoredFlag.shouldApply, "shouldApply should preserve explicit false value")
        XCTAssertEqual(restoredFlag.value?.asStructure()?["size"]?.asInteger(), 42)
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
