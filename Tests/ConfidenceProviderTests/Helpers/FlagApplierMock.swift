import Foundation
import XCTest

@testable import ConfidenceProvider

class FlagApplierMock: FlagApplier {
    var applyCallCount = 0
    var applyExpectation = XCTestExpectation(description: "Flag Applied")

    init(expectedApplies: Int = 1) {
        applyExpectation.expectedFulfillmentCount = expectedApplies
    }

    func apply(flagName: String, resolveToken: String) async {
        applyCallCount += 1
        applyExpectation.fulfill()
    }
}
