import Foundation
import OpenFeature
import XCTest

@testable import Confidence

class PersistentProviderCacheTest: XCTestCase {
    lazy var cache = InMemoryProviderCache.from(storage: storage)
    let storage = DefaultStorage(filePath: "resolver.flags.cache")

    override func setUp() {
        try? storage.clear()

        super.setUp()
    }

    func testCacheStoresValues() throws {
        let flag = "flag"
        let resolveToken = "resolveToken1"
        let ctx = MutableContext(targetingKey: "key", structure: MutableStructure())
        let value = ResolvedValue(
            value: Value.double(3.14),
            flag: flag,
            resolveReason: .match)

        try storage.save(data: [value].toCacheData(context: ctx, resolveToken: resolveToken))
        cache = InMemoryProviderCache.from(storage: storage)

        let cachedValue = try cache.getValue(flag: flag, ctx: ctx)
        XCTAssertEqual(cachedValue?.resolvedValue, value)
        XCTAssertFalse(cachedValue?.needsUpdate ?? true)
        XCTAssertFalse(cachedValue?.needsUpdate ?? true)
        XCTAssertEqual(cachedValue?.resolveToken, resolveToken)
    }

    func testCachePersistsData() throws {
        let flag1 = "flag1"
        let flag2 = "flag2"
        let resolveToken = "resolveToken1"
        let ctx = MutableContext(targetingKey: "key", structure: MutableStructure())
        let value1 = ResolvedValue(
            value: Value.double(3.14),
            flag: "flag1",
            resolveReason: .match)
        let value2 = ResolvedValue(
            value: Value.string("test"),
            flag: "flag2",
            resolveReason: .match)
        XCTAssertFalse(try FileManager.default.fileExists(atPath: storage.getConfigUrl().backport.path))

        try storage.save(data: [value1, value2].toCacheData(context: ctx, resolveToken: resolveToken))
        cache = InMemoryProviderCache.from(storage: storage)

        expectToEventually(
            (try? FileManager.default.fileExists(atPath: storage.getConfigUrl().backport.path)) ?? false)

        let newCache = InMemoryProviderCache.from(
            storage: DefaultStorage(filePath: "resolver.flags.cache"))
        let cachedValue1 = try newCache.getValue(flag: flag1, ctx: ctx)
        let cachedValue2 = try newCache.getValue(flag: flag2, ctx: ctx)
        XCTAssertEqual(cachedValue1?.resolvedValue, value1)
        XCTAssertEqual(cachedValue2?.resolvedValue, value2)
        XCTAssertEqual(cachedValue1?.needsUpdate, false)
        XCTAssertEqual(cachedValue2?.needsUpdate, false)
        XCTAssertEqual(cachedValue1?.resolveToken, resolveToken)
        XCTAssertEqual(cachedValue2?.resolveToken, resolveToken)
    }

    func testNoValueFound() throws {
        let ctx = MutableContext(targetingKey: "key", structure: MutableStructure())

        try storage.clear()

        let cachedValue = try cache.getValue(flag: "flag", ctx: ctx)
        XCTAssertNil(cachedValue?.resolvedValue.value)
    }

    func testChangedContextRequiresUpdate() throws {
        let flag = "flag"
        let resolveToken = "resolveToken1"
        let ctx1 = MutableContext(targetingKey: "key", structure: MutableStructure(attributes: ["test": .integer(3)]))
        let ctx2 = MutableContext(targetingKey: "key", structure: MutableStructure(attributes: ["test": .integer(4)]))

        let value = ResolvedValue(
            value: Value.double(3.14),
            flag: flag,
            resolveReason: .match)
        try storage.save(data: [value].toCacheData(context: ctx1, resolveToken: resolveToken))
        cache = InMemoryProviderCache.from(storage: storage)

        let cachedValue = try cache.getValue(flag: flag, ctx: ctx2)
        XCTAssertEqual(cachedValue?.resolvedValue, value)
        XCTAssertTrue(cachedValue?.needsUpdate ?? false)
    }
}
