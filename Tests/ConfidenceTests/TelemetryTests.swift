// swiftlint:disable file_length
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

// swiftlint:disable:next type_body_length
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
        XCTAssertEqual(result.reason, .error)
        XCTAssertEqual(result.errorCode, .flagNotFound)
    }

    func testMapReason_errorCode_typeMismatch() {
        let result = Telemetry.mapEvaluationReason(reason: .match, errorCode: .typeMismatch())
        XCTAssertEqual(result.reason, .error)
        XCTAssertEqual(result.errorCode, .typeMismatch)
    }

    func testMapReason_errorCode_evaluationError() {
        let result = Telemetry.mapEvaluationReason(reason: .match, errorCode: .evaluationError)
        XCTAssertEqual(result.reason, .error)
        XCTAssertEqual(result.errorCode, .general)
    }

    func testMapReason_errorCode_providerNotReady() {
        let result = Telemetry.mapEvaluationReason(reason: .match, errorCode: .providerNotReady)
        XCTAssertEqual(result.reason, .error)
        XCTAssertEqual(result.errorCode, .providerNotReady)
    }

    func testMapReason_errorCode_parseError() {
        let result = Telemetry.mapEvaluationReason(reason: .match, errorCode: .parseError(message: "bad"))
        XCTAssertEqual(result.reason, .error)
        XCTAssertEqual(result.errorCode, .parseError)
    }

    func testMapReason_errorCode_generalError() {
        let result = Telemetry.mapEvaluationReason(reason: .match, errorCode: .generalError(message: "oops"))
        XCTAssertEqual(result.reason, .error)
        XCTAssertEqual(result.errorCode, .general)
    }

    func testMapReason_errorCode_invalidContext() {
        let result = Telemetry.mapEvaluationReason(reason: .match, errorCode: .invalidContext)
        XCTAssertEqual(result.reason, .error)
        XCTAssertEqual(result.errorCode, .invalidContext)
    }

    func testMapReason_match() {
        let result = Telemetry.mapEvaluationReason(reason: .match, errorCode: nil)
        XCTAssertEqual(result.reason, .targetingMatch)
        XCTAssertEqual(result.errorCode, .unspecified)
    }

    func testMapReason_noSegmentMatch() {
        let result = Telemetry.mapEvaluationReason(reason: .noSegmentMatch, errorCode: nil)
        XCTAssertEqual(result.reason, .default)
        XCTAssertEqual(result.errorCode, .unspecified)
    }

    func testMapReason_noTreatmentMatch() {
        let result = Telemetry.mapEvaluationReason(reason: .noTreatmentMatch, errorCode: nil)
        XCTAssertEqual(result.reason, .default)
        XCTAssertEqual(result.errorCode, .unspecified)
    }

    func testMapReason_stale() {
        let result = Telemetry.mapEvaluationReason(reason: .stale, errorCode: nil)
        XCTAssertEqual(result.reason, .stale)
        XCTAssertEqual(result.errorCode, .unspecified)
    }

    func testMapReason_archived() {
        let result = Telemetry.mapEvaluationReason(reason: .archived, errorCode: nil)
        XCTAssertEqual(result.reason, .disabled)
        XCTAssertEqual(result.errorCode, .unspecified)
    }

    func testMapReason_error() {
        let result = Telemetry.mapEvaluationReason(reason: .error, errorCode: nil)
        XCTAssertEqual(result.reason, .error)
        XCTAssertEqual(result.errorCode, .general)
    }

    func testMapReason_targetingKeyError() {
        let result = Telemetry.mapEvaluationReason(reason: .targetingKeyError, errorCode: nil)
        XCTAssertEqual(result.reason, .error)
        XCTAssertEqual(result.errorCode, .targetingKeyMissing)
    }

    func testMapReason_unspecified() {
        let result = Telemetry.mapEvaluationReason(reason: .unspecified, errorCode: nil)
        XCTAssertEqual(result.reason, .unspecified)
        XCTAssertEqual(result.errorCode, .unspecified)
    }

    func testMapReason_unknown() {
        let result = Telemetry.mapEvaluationReason(reason: .unknown, errorCode: nil)
        XCTAssertEqual(result.reason, .unspecified)
        XCTAssertEqual(result.errorCode, .unspecified)
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

    func testEncodingEvaluationTrace_match() throws {
        let telemetry = makeTelemetry()
        telemetry.trackEvaluation(reason: .match, errorCode: nil)

        let monitoring = try decodeMonitoring(telemetry.encodedHeaderValue())
        let traces = monitoring.libraryTraces[0].traces
        XCTAssertEqual(traces.count, 1)

        let trace = traces[0]
        XCTAssertEqual(trace.id, .flagEvaluation)
        XCTAssertEqual(trace.evaluationTrace.reason, .targetingMatch)
        XCTAssertEqual(trace.evaluationTrace.errorCode, .unspecified)
    }

    func testEncodingEvaluationTrace_stale() throws {
        let telemetry = makeTelemetry()
        telemetry.trackEvaluation(reason: .stale, errorCode: nil)

        let trace = try decodeMonitoring(telemetry.encodedHeaderValue()).libraryTraces[0].traces[0]
        XCTAssertEqual(trace.id, .flagEvaluation)
        XCTAssertEqual(trace.evaluationTrace.reason, .stale)
        XCTAssertEqual(trace.evaluationTrace.errorCode, .unspecified)
    }

    func testEncodingEvaluationTrace_typeMismatch() throws {
        let telemetry = makeTelemetry()
        telemetry.trackEvaluation(reason: .match, errorCode: .typeMismatch())

        let trace = try decodeMonitoring(telemetry.encodedHeaderValue()).libraryTraces[0].traces[0]
        XCTAssertEqual(trace.evaluationTrace.reason, .error)
        XCTAssertEqual(trace.evaluationTrace.errorCode, .typeMismatch)
    }

    func testEncodingEvaluationTrace_flagNotFound() throws {
        let telemetry = makeTelemetry()
        telemetry.trackEvaluation(reason: .match, errorCode: .flagNotFound)

        let trace = try decodeMonitoring(telemetry.encodedHeaderValue()).libraryTraces[0].traces[0]
        XCTAssertEqual(trace.evaluationTrace.reason, .error)
        XCTAssertEqual(trace.evaluationTrace.errorCode, .flagNotFound)
    }

    func testEncodingEvaluationTrace_error() throws {
        let telemetry = makeTelemetry()
        telemetry.trackEvaluation(reason: .error, errorCode: nil)

        let trace = try decodeMonitoring(telemetry.encodedHeaderValue()).libraryTraces[0].traces[0]
        XCTAssertEqual(trace.evaluationTrace.reason, .error)
        XCTAssertEqual(trace.evaluationTrace.errorCode, .general)
    }

    func testEncodingMultipleEvaluationTraces() throws {
        let telemetry = makeTelemetry()
        telemetry.trackEvaluation(reason: .match, errorCode: nil)
        telemetry.trackEvaluation(reason: .stale, errorCode: nil)
        telemetry.trackEvaluation(reason: .match, errorCode: .typeMismatch())

        let traces = try decodeMonitoring(telemetry.encodedHeaderValue()).libraryTraces[0].traces
        XCTAssertEqual(traces.count, 3)
        XCTAssertEqual(traces[0].evaluationTrace.reason, .targetingMatch)
        XCTAssertEqual(traces[0].evaluationTrace.errorCode, .unspecified)
        XCTAssertEqual(traces[1].evaluationTrace.reason, .stale)
        XCTAssertEqual(traces[1].evaluationTrace.errorCode, .unspecified)
        XCTAssertEqual(traces[2].evaluationTrace.reason, .error)
        XCTAssertEqual(traces[2].evaluationTrace.errorCode, .typeMismatch)
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
        XCTAssertEqual(traces[1].evaluationTrace.reason, .targetingMatch)

        XCTAssertEqual(traces[2].id, .flagEvaluation)
        XCTAssertEqual(traces[2].evaluationTrace.reason, .stale)
    }

    // MARK: - Library configuration

    func testLibraryDefaultIsConfidence() throws {
        let telemetry = makeTelemetry()
        let monitoring = try decodeMonitoring(telemetry.encodedHeaderValue())
        XCTAssertEqual(monitoring.libraryTraces[0].library, .confidence)
    }

    func testSetLibraryOpenFeature() throws {
        let telemetry = makeTelemetry()
        telemetry.library = .openFeature
        let monitoring = try decodeMonitoring(telemetry.encodedHeaderValue())
        XCTAssertEqual(monitoring.libraryTraces[0].library, .openFeature)
    }

    // MARK: - Snapshot-and-clear semantics

    func testMultipleSnapshotClearCycles() throws {
        let telemetry = makeTelemetry()

        // Cycle 1: add traces, snapshot clears them
        telemetry.trackEvaluation(reason: .match, errorCode: nil)
        telemetry.trackResolveLatency(durationMs: 50, status: .success)
        let first = try decodeMonitoring(telemetry.encodedHeaderValue())
        XCTAssertEqual(first.libraryTraces[0].traces.count, 2)

        // Cycle 2: empty after clear
        let second = try decodeMonitoring(telemetry.encodedHeaderValue())
        XCTAssertTrue(second.libraryTraces[0].traces.isEmpty)

        // Cycle 3: new traces accumulate independently
        telemetry.trackEvaluation(reason: .stale, errorCode: nil)
        let third = try decodeMonitoring(telemetry.encodedHeaderValue())
        XCTAssertEqual(third.libraryTraces[0].traces.count, 1)
        XCTAssertEqual(third.libraryTraces[0].traces[0].evaluationTrace.reason, .stale)
    }

    func testSdkPropertyReturnsCorrectValues() {
        let telemetry = Telemetry(sdkId: "MY_SDK", library: .confidence, libraryVersion: "2.0.0")
        let sdk = telemetry.sdk
        XCTAssertEqual(sdk.id, "MY_SDK")
        XCTAssertEqual(sdk.version, "2.0.0")
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

    func testConcurrentTrackAndSnapshot() throws {
        let telemetry = makeTelemetry()
        let group = DispatchGroup()
        let iterations = 200
        let totalTraces = Atomic(0)

        // Writers: continuously add traces
        for i in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                telemetry.trackEvaluation(reason: .match, errorCode: nil)
                if i % 3 == 0 {
                    telemetry.trackResolveLatency(durationMs: UInt64(i), status: .success)
                }
                group.leave()
            }
        }

        // Readers: concurrently snapshot-and-clear
        for _ in 0..<10 {
            group.enter()
            DispatchQueue.global().async {
                let monitoring = try? self.decodeMonitoring(telemetry.encodedHeaderValue())
                let count = monitoring?.libraryTraces[0].traces.count ?? 0
                totalTraces.add(count)
                group.leave()
            }
        }

        group.wait()

        // Final drain
        let remaining = try decodeMonitoring(telemetry.encodedHeaderValue()).libraryTraces[0].traces.count
        let total = totalTraces.value + remaining
        // iterations evaluations + iterations/3 resolve traces (i = 0, 3, 6, ... 198 → 67 values)
        let expectedResolves = (0..<iterations).filter { $0 % 3 == 0 }.count
        XCTAssertEqual(total, iterations + expectedResolves)
    }

    func testConcurrentLibrarySetAndEncode() throws {
        let telemetry = makeTelemetry()
        let group = DispatchGroup()

        // Flip library concurrently while encoding
        for i in 0..<200 {
            group.enter()
            DispatchQueue.global().async {
                if i % 2 == 0 {
                    telemetry.library = .openFeature
                } else {
                    telemetry.library = .confidence
                }
                group.leave()
            }
            group.enter()
            DispatchQueue.global().async {
                telemetry.trackEvaluation(reason: .match, errorCode: nil)
                // Must not crash; library must be one of the two valid values
                let monitoring = try? self.decodeMonitoring(telemetry.encodedHeaderValue())
                if let lib = monitoring?.libraryTraces[0].library {
                    XCTAssertTrue(lib == .confidence || lib == .openFeature)
                }
                group.leave()
            }
        }

        group.wait()
    }

    func testConcurrentSnapshotsDoNotDuplicateTraces() throws {
        let telemetry = makeTelemetry()
        let iterations = 500
        let totalTraces = Atomic(0)

        // Pre-fill traces
        for _ in 0..<iterations {
            telemetry.trackEvaluation(reason: .match, errorCode: nil)
        }

        // Multiple concurrent snapshots — each trace must appear exactly once
        let group = DispatchGroup()
        for _ in 0..<20 {
            group.enter()
            DispatchQueue.global().async {
                let monitoring = try? self.decodeMonitoring(telemetry.encodedHeaderValue())
                let count = monitoring?.libraryTraces[0].traces.count ?? 0
                totalTraces.add(count)
                group.leave()
            }
        }

        group.wait()
        let remaining = try decodeMonitoring(telemetry.encodedHeaderValue()).libraryTraces[0].traces.count
        XCTAssertEqual(totalTraces.value + remaining, iterations, "Traces must not be duplicated or lost")
    }
}

// MARK: - Thread-safe counter for tests

private final class Atomic: @unchecked Sendable {
    private var _value: Int
    private let lock = NSLock()

    init(_ value: Int) { _value = value }

    var value: Int { lock.withLock { _value } }

    func add(_ delta: Int) { lock.withLock { _value += delta } }
}
