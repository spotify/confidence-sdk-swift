import Foundation
import OpenFeature
import XCTest

@testable import Confidence

class LocalStorageResolverTest: XCTestCase {
    func testStaleValueFromCache() throws {
        let cache = TestCache(returnType: .oldValue)
        let resolver = LocalStorageResolver(cache: cache)

        let ctx = MutableContext(targetingKey: "key", structure: MutableStructure())
        XCTAssertThrowsError(
            try resolver.resolve(flag: "test", ctx: ctx)
        ) { error in
            XCTAssertEqual(
                error as? ConfidenceError, ConfidenceError.cachedValueExpired)
        }
    }

    func testMissingValueFromCache() throws {
        let cache = TestCache(returnType: .noValue)
        let resolver = LocalStorageResolver(cache: cache)

        let ctx = MutableContext(targetingKey: "key", structure: MutableStructure())
        XCTAssertThrowsError(
            try resolver.resolve(flag: "test", ctx: ctx)
        ) { error in
            XCTAssertEqual(
                error as? OpenFeatureError, OpenFeatureError.flagNotFoundError(key: "test"))
        }
    }
}

class TestCache: ProviderCache {
    private let returnType: ReturnType
    private let mockedResolvedValue = ResolvedValue(flag: "flag1", resolveReason: .match)

    init(returnType: ReturnType) {
        self.returnType = returnType
    }

    func getValue(flag: String, ctx: EvaluationContext) -> CacheGetValueResult? {
        switch returnType {
        case .noValue:
            return nil
        case .oldValue:
            return CacheGetValueResult(resolvedValue: mockedResolvedValue, needsUpdate: true, resolveToken: "tok1")
        }
    }

    func clearAndSetValues(
        values: [ResolvedValue], ctx: OpenFeature.EvaluationContext, resolveToken: String
    ) {}

    func getCurResolveToken() -> String? {
        return nil
    }
}

extension TestCache {
    enum ReturnType {
        case noValue
        case oldValue
    }
}
