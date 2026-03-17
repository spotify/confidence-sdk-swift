import Foundation
import XCTest

@testable import Confidence

class TelemetryProducerMock: TelemetryProducer {
    var reportCallCount = 0
    var reportedErrors: [(flagName: String, errorCode: ErrorCode, errorMessage: String?)] = []
    var reportExpectation = XCTestExpectation(description: "Telemetry Reported")

    init(expectedReports: Int = 1) {
        reportExpectation.expectedFulfillmentCount = expectedReports
    }

    func report(flagName: String, errorCode: ErrorCode, errorMessage: String?) async {
        reportCallCount += 1
        reportedErrors.append((flagName: flagName, errorCode: errorCode, errorMessage: errorMessage))
        reportExpectation.fulfill()
    }
}
