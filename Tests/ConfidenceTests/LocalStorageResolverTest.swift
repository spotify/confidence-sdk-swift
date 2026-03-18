import Foundation
import XCTest

@testable import Confidence

class LocalStorageResolverTest: XCTestCase {
    func testStaleValueFromCache() throws {
        let resolvedValue = ResolvedValue(
            value: .init(structure: ["string": .init(string: "Value")]),
            flag: "flag_name",
            resolveReason: .match,
            shouldApply: true
        )
        let flagResolution = FlagResolution(
            context: ["hey": ConfidenceValue(string: "old value")],
            flags: [resolvedValue],
            resolveToken: ""
        )

        XCTAssertNoThrow(
            flagResolution.evaluate(
                flagName: "flag_name.string", defaultValue: "default", context: [:])
        )
    }

    func testMissingValueFromCache() throws {
        let resolvedValue = ResolvedValue(
            value: .init(structure: ["string": .init(string: "Value")]),
            flag: "flag_name",
            resolveReason: .match,
            shouldApply: true
        )
        let context =
            ["hey": ConfidenceValue(string: "old value")]
        let flagResolution = FlagResolution(context: context, flags: [resolvedValue], resolveToken: "")
        let evaluation = flagResolution.evaluate(flagName: "new_flag_name", defaultValue: "default", context: context)
        XCTAssertEqual(evaluation.value, "default")
        XCTAssertNil(evaluation.variant)
        XCTAssertEqual(evaluation.reason, .error)
        XCTAssertEqual(evaluation.errorCode, .flagNotFound)
        XCTAssertEqual(evaluation.errorMessage, "Flag 'new_flag_name' not found in local cache")
    }

    // MARK: - Telemetry resolve_rate tests

    func testTrackResolve_matchEvaluation() throws {
        let telemetry = TelemetryProducerMock()
        let context: ConfidenceStruct = ["key": ConfidenceValue(string: "val")]
        let resolvedValue = ResolvedValue(
            value: .init(structure: ["string": .init(string: "Value")]),
            flag: "flag_name",
            resolveReason: .match,
            shouldApply: true
        )
        let flagResolution = FlagResolution(context: context, flags: [resolvedValue], resolveToken: "token1")

        let evaluation = flagResolution.evaluate(
            flagName: "flag_name.string",
            defaultValue: "default",
            context: context,
            telemetryProducer: telemetry
        )

        XCTAssertEqual(evaluation.reason, .match)
        let expectation = XCTestExpectation(description: "trackResolve called")
        Task {
            try await Task.sleep(nanoseconds: 100_000_000)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(telemetry.trackResolveCallCount, 1)
        XCTAssertEqual(telemetry.trackedReasons, [.match])
        XCTAssertEqual(telemetry.reportCallCount, 0)
    }

    func testTrackResolve_staleEvaluation() throws {
        let telemetry = TelemetryProducerMock()
        let resolveContext: ConfidenceStruct = ["key": ConfidenceValue(string: "old")]
        let evalContext: ConfidenceStruct = ["key": ConfidenceValue(string: "new")]
        let resolvedValue = ResolvedValue(
            value: .init(structure: ["string": .init(string: "Value")]),
            flag: "flag_name",
            resolveReason: .match,
            shouldApply: true
        )
        let flagResolution = FlagResolution(context: resolveContext, flags: [resolvedValue], resolveToken: "token1")

        let evaluation = flagResolution.evaluate(
            flagName: "flag_name.string",
            defaultValue: "default",
            context: evalContext,
            telemetryProducer: telemetry
        )

        XCTAssertEqual(evaluation.reason, .stale)
        let expectation = XCTestExpectation(description: "trackResolve called")
        Task {
            try await Task.sleep(nanoseconds: 100_000_000)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(telemetry.trackResolveCallCount, 1)
        XCTAssertEqual(telemetry.trackedReasons, [.stale])
        XCTAssertEqual(telemetry.reportCallCount, 0)
    }

    func testTrackResolve_noSegmentMatch() throws {
        let telemetry = TelemetryProducerMock()
        let context: ConfidenceStruct = [:]
        let resolvedValue = ResolvedValue(
            variant: "control",
            value: .init(structure: ["string": .init(string: "Value")]),
            flag: "flag_name",
            resolveReason: .noSegmentMatch,
            shouldApply: true
        )
        let flagResolution = FlagResolution(context: context, flags: [resolvedValue], resolveToken: "token1")

        let evaluation = flagResolution.evaluate(
            flagName: "flag_name.string",
            defaultValue: "default",
            context: context,
            telemetryProducer: telemetry
        )

        XCTAssertEqual(evaluation.reason, .noSegmentMatch)
        let expectation = XCTestExpectation(description: "trackResolve called")
        Task {
            try await Task.sleep(nanoseconds: 100_000_000)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(telemetry.trackResolveCallCount, 1)
        XCTAssertEqual(telemetry.trackedReasons, [.noSegmentMatch])
    }

    func testTrackResolve_notCalledForFlagNotFound() throws {
        let telemetry = TelemetryProducerMock()
        let context: ConfidenceStruct = [:]
        let resolvedValue = ResolvedValue(
            value: .init(structure: ["string": .init(string: "Value")]),
            flag: "flag_name",
            resolveReason: .match,
            shouldApply: true
        )
        let flagResolution = FlagResolution(context: context, flags: [resolvedValue], resolveToken: "token1")

        let evaluation = flagResolution.evaluate(
            flagName: "missing_flag.string",
            defaultValue: "default",
            context: context,
            telemetryProducer: telemetry
        )

        XCTAssertEqual(evaluation.reason, .error)
        XCTAssertEqual(evaluation.errorCode, .flagNotFound)
        let expectation = XCTestExpectation(description: "report called")
        Task {
            try await Task.sleep(nanoseconds: 100_000_000)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(telemetry.trackResolveCallCount, 0)
        XCTAssertEqual(telemetry.reportCallCount, 1)
    }

    func testTrackResolve_notCalledWhenShouldApplyFalse() throws {
        let telemetry = TelemetryProducerMock()
        let context: ConfidenceStruct = [:]
        let resolvedValue = ResolvedValue(
            value: .init(structure: ["string": .init(string: "Value")]),
            flag: "flag_name",
            resolveReason: .match,
            shouldApply: false
        )
        let flagResolution = FlagResolution(context: context, flags: [resolvedValue], resolveToken: "token1")

        let evaluation = flagResolution.evaluate(
            flagName: "flag_name.string",
            defaultValue: "default",
            context: context,
            telemetryProducer: telemetry
        )

        XCTAssertEqual(evaluation.reason, .match)
        let expectation = XCTestExpectation(description: "wait for task")
        Task {
            try await Task.sleep(nanoseconds: 100_000_000)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(telemetry.trackResolveCallCount, 0)
        XCTAssertEqual(telemetry.reportCallCount, 0)
    }

    func testTrackResolve_notCalledForBackendError() throws {
        let telemetry = TelemetryProducerMock()
        let context: ConfidenceStruct = [:]
        let resolvedValue = ResolvedValue(
            value: .init(structure: ["string": .init(string: "Value")]),
            flag: "flag_name",
            resolveReason: .targetingKeyError,
            shouldApply: true
        )
        let flagResolution = FlagResolution(context: context, flags: [resolvedValue], resolveToken: "token1")

        let evaluation = flagResolution.evaluate(
            flagName: "flag_name.string",
            defaultValue: "default",
            context: context,
            telemetryProducer: telemetry
        )

        XCTAssertEqual(evaluation.errorCode, .invalidContext)
        let expectation = XCTestExpectation(description: "report called")
        Task {
            try await Task.sleep(nanoseconds: 100_000_000)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(telemetry.trackResolveCallCount, 0)
        XCTAssertEqual(telemetry.reportCallCount, 1)
    }
}
