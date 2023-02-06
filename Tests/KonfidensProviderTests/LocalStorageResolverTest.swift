import Foundation
import OpenFeature
import XCTest

@testable import KonfidensProvider

class LocalStorageResolverTest: XCTestCase {
    func testStaleValueFromCache() throws {
        let cache = TestCache(returnType: .oldValue)
        let resolver = LocalStorageResolver(cache: cache)

        let ctx = MutableContext(targetingKey: "key", structure: MutableStructure())
        XCTAssertThrowsError(
            try resolver.resolve(flag: "test", ctx: ctx)
        ) { error in
            XCTAssertEqual(
                error as? KonfidensError, KonfidensError.cachedValueExpired)
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
                error as? KonfidensError, KonfidensError.flagNotFoundInCache)
        }
    }
}

class TestCache: BatchProviderCache {
    private let returnType: ReturnType
    private let mockedResolvedValue = ResolvedValue(contextHash: "", flag: "flag1", applyStatus: .applied)

    init(returnType: ReturnType) {
        self.returnType = returnType
    }

    func getValue(flag: String, ctx: EvaluationContext) -> KonfidensProvider.CacheGetValueResult? {
        switch returnType {
        case .noValue:
            return nil
        case .oldValue:
            return CacheGetValueResult(resolvedValue: mockedResolvedValue, needsUpdate: true, resolveToken: "tok1")
        }
    }

    func clearAndSetValues(
        values: [KonfidensProvider.ResolvedValue], ctx: OpenFeature.EvaluationContext, resolveToken: String
    ) {}

    func updateApplyStatus(
        flag: String,
        ctx: OpenFeature.EvaluationContext,
        resolveToken: String,
        applyStatus: KonfidensProvider.ApplyStatus
    ) throws {}

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
