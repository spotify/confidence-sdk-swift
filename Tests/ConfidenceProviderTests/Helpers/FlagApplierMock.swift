import Foundation

@testable import ConfidenceProvider

class FlagApplierMock: FlagApplier {
    var applyCallCount = 0

    func apply(flagName: String, resolveToken: String) {
        applyCallCount += 1
    }
}
