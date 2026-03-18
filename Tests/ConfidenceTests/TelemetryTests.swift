import Foundation
import SwiftProtobuf
import XCTest

@testable import Confidence

// Type aliases for readability
private typealias ProtoMonitoring = Confidence_Telemetry_V1_Monitoring
private typealias ProtoLibraryTraces = Confidence_Telemetry_V1_LibraryTraces
private typealias ProtoTrace = Confidence_Telemetry_V1_LibraryTraces.Trace
private typealias ProtoRequestTrace = Confidence_Telemetry_V1_LibraryTraces.Trace.RequestTrace
private typealias ProtoEvaluationTrace = Confidence_Telemetry_V1_LibraryTraces.Trace.EvaluationTrace

class TelemetryTests: XCTestCase {
    private func makeTelemetry(version: String = "1.0.0") -> Telemetry {
        Telemetry(sdkId: "SDK_ID_SWIFT_CONFIDENCE", library: .confidence, libraryVersion: version)
    }

    private func decodeMonitoring(_ base64: String) throws -> ProtoMonitoring {
        let data = try XCTUnwrap(Data(base64Encoded: base64))
        return try ProtoMonitoring(serializedBytes: data)
    }

    // MARK: - mapEvaluationReason

    func testMapReason_errorCode_flagNotFound() {
        let result = Telemetry.mapEvaluationReason(reason: .match, errorCode: .flagNotFound)
        XCTAssertEqual(result, .flagNotFound)
    }

    func testMapReason_errorCode_typeMismatch() {
        let result = Telemetry.mapEvaluationReason(reason: .match, errorCode: .typeMismatch())
        XCTAssertEqual(result, .typeMismatch)
    }

    func testMapReason_errorCode_evaluationError() {
        let result = Telemetry.mapEvaluationReason(reason: .match, errorCode: .evaluationError)
        XCTAssertEqual(result, .error)
    }

    func testMapReason_errorCode_providerNotReady() {
        let result = Telemetry.mapEvaluationReason(reason: .match, errorCode: .providerNotReady)
        XCTAssertEqual(result, .error)
    }

    func testMapReason_errorCode_parseError() {
        let result = Telemetry.mapEvaluationReason(reason: .match, errorCode: .parseError(message: "bad"))
        XCTAssertEqual(result, .error)
    }

    func testMapReason_errorCode_generalError() {
        let result = Telemetry.mapEvaluationReason(reason: .match, errorCode: .generalError(message: "oops"))
        XCTAssertEqual(result, .error)
    }

    func testMapReason_errorCode_invalidContext() {
        let result = Telemetry.mapEvaluationReason(reason: .match, errorCode: .invalidContext)
        XCTAssertEqual(result, .error)
    }

    func testMapReason_match() {
        let result = Telemetry.mapEvaluationReason(reason: .match, errorCode: nil)
        XCTAssertEqual(result, .success)
    }

    func testMapReason_noSegmentMatch() {
        let result = Telemetry.mapEvaluationReason(reason: .noSegmentMatch, errorCode: nil)
        XCTAssertEqual(result, .success)
    }

    func testMapReason_noTreatmentMatch() {
        let result = Telemetry.mapEvaluationReason(reason: .noTreatmentMatch, errorCode: nil)
        XCTAssertEqual(result, .success)
    }

    func testMapReason_stale() {
        let result = Telemetry.mapEvaluationReason(reason: .stale, errorCode: nil)
        XCTAssertEqual(result, .stale)
    }

    func testMapReason_archived() {
        let result = Telemetry.mapEvaluationReason(reason: .archived, errorCode: nil)
        XCTAssertEqual(result, .error)
    }

    func testMapReason_error() {
        let result = Telemetry.mapEvaluationReason(reason: .error, errorCode: nil)
        XCTAssertEqual(result, .error)
    }

    func testMapReason_targetingKeyError() {
        let result = Telemetry.mapEvaluationReason(reason: .targetingKeyError, errorCode: nil)
        XCTAssertEqual(result, .error)
    }

    func testMapReason_unspecified() {
        let result = Telemetry.mapEvaluationReason(reason: .unspecified, errorCode: nil)
        XCTAssertEqual(result, .unknown)
    }

    func testMapReason_unknown() {
        let result = Telemetry.mapEvaluationReason(reason: .unknown, errorCode: nil)
        XCTAssertEqual(result, .unknown)
    }

    // MARK: - Snapshot and clear

    func testEncodedHeaderClearsTraces() throws {
        let telemetry = makeTelemetry()
        telemetry.trackEvaluation(reason: .match, errorCode: nil)
        telemetry.trackResolveLatency(durationMs: 100, status: .success)

        let first = try decodeMonitoring(telemetry.encodedHeaderValue())
        XCTAssertFalse(first.libraryTraces[0].traces.isEmpty)

        let second = try decodeMonitoring(telemetry.encodedHeaderValue())
        XCTAssertTrue(second.libraryTraces[0].traces.isEmpty)
    }

    // MARK: - Protobuf encoding: baseline (no traces)

    func testEncodingBaseline() throws {
        let telemetry = makeTelemetry(version: "1.4.5")
        let monitoring = try decodeMonitoring(telemetry.encodedHeaderValue())

        XCTAssertEqual(monitoring.platform, .swift)
        XCTAssertEqual(monitoring.libraryTraces.count, 1)

        let lib = monitoring.libraryTraces[0]
        XCTAssertEqual(lib.library, .confidence)
        XCTAssertEqual(lib.libraryVersion, "1.4.5")
        XCTAssertTrue(lib.traces.isEmpty)
    }

    // MARK: - Protobuf encoding: evaluation traces

    func testEncodingEvaluationTrace_success() throws {
        let telemetry = makeTelemetry()
        telemetry.trackEvaluation(reason: .match, errorCode: nil)

        let monitoring = try decodeMonitoring(telemetry.encodedHeaderValue())
        let traces = monitoring.libraryTraces[0].traces
        XCTAssertEqual(traces.count, 1)

        let trace = traces[0]
        XCTAssertEqual(trace.id, .flagEvaluation)
        XCTAssertEqual(trace.evaluationTrace.evaluationReason, .success)
    }

    func testEncodingEvaluationTrace_stale() throws {
        let telemetry = makeTelemetry()
        telemetry.trackEvaluation(reason: .stale, errorCode: nil)

        let trace = try decodeMonitoring(telemetry.encodedHeaderValue()).libraryTraces[0].traces[0]
        XCTAssertEqual(trace.id, .flagEvaluation)
        XCTAssertEqual(trace.evaluationTrace.evaluationReason, .stale)
    }

    func testEncodingEvaluationTrace_typeMismatch() throws {
        let telemetry = makeTelemetry()
        telemetry.trackEvaluation(reason: .match, errorCode: .typeMismatch())

        let trace = try decodeMonitoring(telemetry.encodedHeaderValue()).libraryTraces[0].traces[0]
        XCTAssertEqual(trace.evaluationTrace.evaluationReason, .typeMismatch)
    }

    func testEncodingEvaluationTrace_flagNotFound() throws {
        let telemetry = makeTelemetry()
        telemetry.trackEvaluation(reason: .match, errorCode: .flagNotFound)

        let trace = try decodeMonitoring(telemetry.encodedHeaderValue()).libraryTraces[0].traces[0]
        XCTAssertEqual(trace.evaluationTrace.evaluationReason, .flagNotFound)
    }

    func testEncodingEvaluationTrace_error() throws {
        let telemetry = makeTelemetry()
        telemetry.trackEvaluation(reason: .error, errorCode: nil)

        let trace = try decodeMonitoring(telemetry.encodedHeaderValue()).libraryTraces[0].traces[0]
        XCTAssertEqual(trace.evaluationTrace.evaluationReason, .error)
    }

    func testEncodingMultipleEvaluationTraces() throws {
        let telemetry = makeTelemetry()
        telemetry.trackEvaluation(reason: .match, errorCode: nil)
        telemetry.trackEvaluation(reason: .stale, errorCode: nil)
        telemetry.trackEvaluation(reason: .match, errorCode: .typeMismatch())

        let traces = try decodeMonitoring(telemetry.encodedHeaderValue()).libraryTraces[0].traces
        XCTAssertEqual(traces.count, 3)
        XCTAssertEqual(traces[0].evaluationTrace.evaluationReason, .success)
        XCTAssertEqual(traces[1].evaluationTrace.evaluationReason, .stale)
        XCTAssertEqual(traces[2].evaluationTrace.evaluationReason, .typeMismatch)
    }

    // MARK: - Protobuf encoding: resolve traces

    func testEncodingResolveTrace_success() throws {
        let telemetry = makeTelemetry()
        telemetry.trackResolveLatency(durationMs: 42, status: .success)

        let traces = try decodeMonitoring(telemetry.encodedHeaderValue()).libraryTraces[0].traces
        XCTAssertEqual(traces.count, 1)

        let trace = traces[0]
        XCTAssertEqual(trace.id, .resolveLatency)
        XCTAssertEqual(trace.requestTrace.millisecondDuration, 42)
        XCTAssertEqual(trace.requestTrace.status, .success)
    }

    func testEncodingResolveTrace_error() throws {
        let telemetry = makeTelemetry()
        telemetry.trackResolveLatency(durationMs: 500, status: .error)

        let trace = try decodeMonitoring(telemetry.encodedHeaderValue()).libraryTraces[0].traces[0]
        XCTAssertEqual(trace.requestTrace.millisecondDuration, 500)
        XCTAssertEqual(trace.requestTrace.status, .error)
    }

    func testEncodingResolveTrace_timeout() throws {
        let telemetry = makeTelemetry()
        telemetry.trackResolveLatency(durationMs: 30000, status: .timeout)

        let trace = try decodeMonitoring(telemetry.encodedHeaderValue()).libraryTraces[0].traces[0]
        XCTAssertEqual(trace.requestTrace.millisecondDuration, 30000)
        XCTAssertEqual(trace.requestTrace.status, .timeout)
    }

    // MARK: - Protobuf encoding: mixed traces

    func testEncodingMixedTraces() throws {
        let telemetry = makeTelemetry()
        telemetry.trackResolveLatency(durationMs: 150, status: .success)
        telemetry.trackEvaluation(reason: .match, errorCode: nil)
        telemetry.trackEvaluation(reason: .stale, errorCode: nil)

        let traces = try decodeMonitoring(telemetry.encodedHeaderValue()).libraryTraces[0].traces
        XCTAssertEqual(traces.count, 3)

        XCTAssertEqual(traces[0].id, .resolveLatency)
        XCTAssertEqual(traces[0].requestTrace.status, .success)

        XCTAssertEqual(traces[1].id, .flagEvaluation)
        XCTAssertEqual(traces[1].evaluationTrace.evaluationReason, .success)

        XCTAssertEqual(traces[2].id, .flagEvaluation)
        XCTAssertEqual(traces[2].evaluationTrace.evaluationReason, .stale)
    }

    // MARK: - Thread safety

    func testConcurrentTracking() throws {
        let telemetry = makeTelemetry()
        let group = DispatchGroup()
        let iterations = 100

        for _ in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                telemetry.trackEvaluation(reason: .match, errorCode: nil)
                group.leave()
            }
        }
        for _ in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                telemetry.trackResolveLatency(durationMs: 10, status: .success)
                group.leave()
            }
        }

        group.wait()
        let traces = try decodeMonitoring(telemetry.encodedHeaderValue()).libraryTraces[0].traces
        XCTAssertEqual(traces.count, iterations * 2)
    }
}
