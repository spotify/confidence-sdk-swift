import Foundation
import OpenFeature

@testable import Confidence

class ClientMock: ConfidenceClient {
    var applyCount = 0
    var batchApplyCount = 0
    var testMode: TestMode
    var batchItems: [FlagApply] = []

    enum TestMode {
        case success
        case error
    }

    init(testMode: TestMode = .success) {
        self.testMode = testMode
    }

    func resolve(ctx: EvaluationContext) throws -> ResolvesResult {
        return ResolvesResult(resolvedValues: [], resolveToken: "")
    }

    func apply(flag: String, resolveToken: String, applyTime: Date) throws {
        applyCount += 1

        switch testMode {
        case .success:
            return
        case .error:
            throw HttpClientError.invalidResponse
        }
    }

    func apply(resolveToken: String, items: [FlagApply]) throws {
        batchApplyCount += 1
        batchItems = items

        switch testMode {
        case .success:
            return
        case .error:
            throw HttpClientError.invalidResponse
        }
    }

    func resolve(flag: String, ctx: EvaluationContext) throws -> ResolveResult {
        return ResolveResult(resolvedValue: ResolvedValue(flag: "flag1", resolveReason: .match), resolveToken: "")
    }
}
