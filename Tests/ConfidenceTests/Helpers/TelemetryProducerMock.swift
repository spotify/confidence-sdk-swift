import Foundation
import XCTest

@testable import Confidence

struct ReportedError {
    let flagName: String
    let errorCode: ErrorCode
    let errorMessage: String?
}

class TelemetryProducerMock: TelemetryProducer {
    var reportCallCount = 0
    var reportedErrors: [ReportedError] = []
    var reportExpectation = XCTestExpectation(description: "Telemetry Reported")

    var trackResolveCallCount = 0
    var trackedReasons: [ResolveReason] = []
    var flushCallCount = 0

    init(expectedReports: Int = 1) {
        reportExpectation.expectedFulfillmentCount = expectedReports
    }

    func report(flagName: String, errorCode: ErrorCode, errorMessage: String?) async {
        reportCallCount += 1
        reportedErrors.append(ReportedError(flagName: flagName, errorCode: errorCode, errorMessage: errorMessage))
        reportExpectation.fulfill()
    }

    func trackResolve(reason: ResolveReason) async {
        trackResolveCallCount += 1
        trackedReasons.append(reason)
    }

    func flush() async {
        flushCallCount += 1
    }
}
