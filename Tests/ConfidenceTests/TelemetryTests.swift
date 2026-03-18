// swiftlint:disable file_length
import Foundation
import XCTest

@testable import Confidence

class TelemetryTests: XCTestCase {
    private func makeTelemetry(version: String = "1.0.0") -> Telemetry {
        Telemetry(sdkId: "SDK_ID_SWIFT_CONFIDENCE", library: .confidence, libraryVersion: version)
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

    func testEncodedHeaderClearsTraces() {
        let telemetry = makeTelemetry()
        telemetry.trackEvaluation(reason: .match, errorCode: nil)
        telemetry.trackResolveLatency(durationMs: 100, status: .success)

        let first = decodeMonitoring(telemetry.encodedHeaderValue())
        let firstTraces = first.libraryTraces.first
        XCTAssertNotNil(firstTraces)
        XCTAssertFalse(firstTraces?.traces.isEmpty ?? true)

        let second = decodeMonitoring(telemetry.encodedHeaderValue())
        let secondTraces = second.libraryTraces.first
        XCTAssertNotNil(secondTraces)
        XCTAssertTrue(secondTraces?.traces.isEmpty ?? false)
    }

    // MARK: - Protobuf encoding: baseline (no traces)

    func testEncodingBaseline() {
        let telemetry = makeTelemetry(version: "1.4.5")
        let monitoring = decodeMonitoring(telemetry.encodedHeaderValue())

        XCTAssertEqual(monitoring.platform, 3)  // SWIFT
        XCTAssertEqual(monitoring.libraryTraces.count, 1)

        let lib = monitoring.libraryTraces[0]
        XCTAssertEqual(lib.library, 1)  // CONFIDENCE
        XCTAssertEqual(lib.version, "1.4.5")
        XCTAssertTrue(lib.traces.isEmpty)
    }

    // MARK: - Protobuf encoding: evaluation traces

    func testEncodingEvaluationTrace_success() {
        let telemetry = makeTelemetry()
        telemetry.trackEvaluation(reason: .match, errorCode: nil)

        let monitoring = decodeMonitoring(telemetry.encodedHeaderValue())
        let traces = monitoring.libraryTraces[0].traces
        XCTAssertEqual(traces.count, 1)

        let trace = traces[0]
        XCTAssertEqual(trace.traceId, 3)  // FLAG_EVALUATION
        XCTAssertNotNil(trace.evaluationTrace)
        XCTAssertEqual(trace.evaluationTrace?.evaluationReason, 1)  // SUCCESS
    }

    func testEncodingEvaluationTrace_stale() {
        let telemetry = makeTelemetry()
        telemetry.trackEvaluation(reason: .stale, errorCode: nil)

        let trace = decodeMonitoring(telemetry.encodedHeaderValue()).libraryTraces[0].traces[0]
        XCTAssertEqual(trace.evaluationTrace?.evaluationReason, 2)  // STALE
    }

    func testEncodingEvaluationTrace_typeMismatch() {
        let telemetry = makeTelemetry()
        telemetry.trackEvaluation(reason: .match, errorCode: .typeMismatch())

        let trace = decodeMonitoring(telemetry.encodedHeaderValue()).libraryTraces[0].traces[0]
        XCTAssertEqual(trace.evaluationTrace?.evaluationReason, 4)  // TYPE_MISMATCH
    }

    func testEncodingEvaluationTrace_flagNotFound() {
        let telemetry = makeTelemetry()
        telemetry.trackEvaluation(reason: .match, errorCode: .flagNotFound)

        let trace = decodeMonitoring(telemetry.encodedHeaderValue()).libraryTraces[0].traces[0]
        XCTAssertEqual(trace.evaluationTrace?.evaluationReason, 3)  // FLAG_NOT_FOUND
    }

    func testEncodingEvaluationTrace_error() {
        let telemetry = makeTelemetry()
        telemetry.trackEvaluation(reason: .error, errorCode: nil)

        let trace = decodeMonitoring(telemetry.encodedHeaderValue()).libraryTraces[0].traces[0]
        XCTAssertEqual(trace.evaluationTrace?.evaluationReason, 5)  // ERROR
    }

    func testEncodingMultipleEvaluationTraces() {
        let telemetry = makeTelemetry()
        telemetry.trackEvaluation(reason: .match, errorCode: nil)
        telemetry.trackEvaluation(reason: .stale, errorCode: nil)
        telemetry.trackEvaluation(reason: .match, errorCode: .typeMismatch())

        let traces = decodeMonitoring(telemetry.encodedHeaderValue()).libraryTraces[0].traces
        XCTAssertEqual(traces.count, 3)
        XCTAssertEqual(traces[0].evaluationTrace?.evaluationReason, 1)  // SUCCESS
        XCTAssertEqual(traces[1].evaluationTrace?.evaluationReason, 2)  // STALE
        XCTAssertEqual(traces[2].evaluationTrace?.evaluationReason, 4)  // TYPE_MISMATCH
    }

    // MARK: - Protobuf encoding: resolve traces

    func testEncodingResolveTrace_success() {
        let telemetry = makeTelemetry()
        telemetry.trackResolveLatency(durationMs: 42, status: .success)

        let traces = decodeMonitoring(telemetry.encodedHeaderValue()).libraryTraces[0].traces
        XCTAssertEqual(traces.count, 1)

        let trace = traces[0]
        XCTAssertEqual(trace.traceId, 1)  // RESOLVE_LATENCY
        XCTAssertNotNil(trace.requestTrace)
        XCTAssertEqual(trace.requestTrace?.millisecondDuration, 42)
        XCTAssertEqual(trace.requestTrace?.status, 1)  // SUCCESS
    }

    func testEncodingResolveTrace_error() {
        let telemetry = makeTelemetry()
        telemetry.trackResolveLatency(durationMs: 500, status: .error)

        let trace = decodeMonitoring(telemetry.encodedHeaderValue()).libraryTraces[0].traces[0]
        XCTAssertEqual(trace.requestTrace?.millisecondDuration, 500)
        XCTAssertEqual(trace.requestTrace?.status, 2)  // ERROR
    }

    func testEncodingResolveTrace_timeout() {
        let telemetry = makeTelemetry()
        telemetry.trackResolveLatency(durationMs: 30000, status: .timeout)

        let trace = decodeMonitoring(telemetry.encodedHeaderValue()).libraryTraces[0].traces[0]
        XCTAssertEqual(trace.requestTrace?.millisecondDuration, 30000)
        XCTAssertEqual(trace.requestTrace?.status, 3)  // TIMEOUT
    }

    // MARK: - Protobuf encoding: mixed traces

    func testEncodingMixedTraces() {
        let telemetry = makeTelemetry()
        telemetry.trackResolveLatency(durationMs: 150, status: .success)
        telemetry.trackEvaluation(reason: .match, errorCode: nil)
        telemetry.trackEvaluation(reason: .stale, errorCode: nil)

        let traces = decodeMonitoring(telemetry.encodedHeaderValue()).libraryTraces[0].traces
        XCTAssertEqual(traces.count, 3)

        // Resolve traces come first in encoding order
        XCTAssertEqual(traces[0].traceId, 1)  // RESOLVE_LATENCY
        XCTAssertNotNil(traces[0].requestTrace)

        XCTAssertEqual(traces[1].traceId, 3)  // FLAG_EVALUATION
        XCTAssertNotNil(traces[1].evaluationTrace)

        XCTAssertEqual(traces[2].traceId, 3)  // FLAG_EVALUATION
        XCTAssertNotNil(traces[2].evaluationTrace)
    }

    // MARK: - Thread safety

    func testConcurrentTracking() {
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
        let traces = decodeMonitoring(telemetry.encodedHeaderValue()).libraryTraces[0].traces
        XCTAssertEqual(traces.count, iterations * 2)
    }
}

// MARK: - Lightweight protobuf decoder for test verification

extension TelemetryTests {
    struct DecodedMonitoring {
        var libraryTraces: [DecodedLibraryTraces] = []
        var platform: Int = 0
    }

    struct DecodedLibraryTraces {
        var library: Int = 0
        var version: String = ""
        var traces: [DecodedTrace] = []
    }

    struct DecodedTrace {
        var traceId: Int = 0
        var requestTrace: DecodedRequestTrace?
        var evaluationTrace: DecodedEvaluationTrace?
    }

    struct DecodedRequestTrace {
        var millisecondDuration: UInt64 = 0
        var status: Int = 0
    }

    struct DecodedEvaluationTrace {
        var evaluationReason: Int = 0
    }

    func decodeMonitoring(_ base64: String) -> DecodedMonitoring {
        guard let data = Data(base64Encoded: base64) else {
            XCTFail("Invalid base64")
            return DecodedMonitoring()
        }
        let bytes = [UInt8](data)
        var offset = 0
        var monitoring = DecodedMonitoring()

        while offset < bytes.count {
            let (fieldNumber, wireType) = readFieldKey(bytes, &offset)
            switch (fieldNumber, wireType) {
            case (1, 2):
                let payload = readLengthDelimited(bytes, &offset)
                monitoring.libraryTraces.append(decodeLibraryTraces(payload))
            case (2, 0):
                monitoring.platform = Int(readVarint(bytes, &offset))
            default:
                skipField(bytes, &offset, wireType: wireType)
            }
        }
        return monitoring
    }

    private func decodeLibraryTraces(_ bytes: [UInt8]) -> DecodedLibraryTraces {
        var offset = 0
        var lib = DecodedLibraryTraces()

        while offset < bytes.count {
            let (fieldNumber, wireType) = readFieldKey(bytes, &offset)
            switch (fieldNumber, wireType) {
            case (1, 0):
                lib.library = Int(readVarint(bytes, &offset))
            case (2, 2):
                let payload = readLengthDelimited(bytes, &offset)
                lib.version = String(bytes: payload, encoding: .utf8) ?? ""
            case (3, 2):
                let payload = readLengthDelimited(bytes, &offset)
                lib.traces.append(decodeTrace(payload))
            default:
                skipField(bytes, &offset, wireType: wireType)
            }
        }
        return lib
    }

    private func decodeTrace(_ bytes: [UInt8]) -> DecodedTrace {
        var offset = 0
        var trace = DecodedTrace()

        while offset < bytes.count {
            let (fieldNumber, wireType) = readFieldKey(bytes, &offset)
            switch (fieldNumber, wireType) {
            case (1, 0):
                trace.traceId = Int(readVarint(bytes, &offset))
            case (3, 2):
                let payload = readLengthDelimited(bytes, &offset)
                trace.requestTrace = decodeRequestTrace(payload)
            case (5, 2):
                let payload = readLengthDelimited(bytes, &offset)
                trace.evaluationTrace = decodeEvaluationTrace(payload)
            default:
                skipField(bytes, &offset, wireType: wireType)
            }
        }
        return trace
    }

    private func decodeRequestTrace(_ bytes: [UInt8]) -> DecodedRequestTrace {
        var offset = 0
        var trace = DecodedRequestTrace()

        while offset < bytes.count {
            let (fieldNumber, wireType) = readFieldKey(bytes, &offset)
            switch (fieldNumber, wireType) {
            case (1, 0):
                trace.millisecondDuration = readVarint(bytes, &offset)
            case (2, 0):
                trace.status = Int(readVarint(bytes, &offset))
            default:
                skipField(bytes, &offset, wireType: wireType)
            }
        }
        return trace
    }

    private func decodeEvaluationTrace(_ bytes: [UInt8]) -> DecodedEvaluationTrace {
        var offset = 0
        var trace = DecodedEvaluationTrace()

        while offset < bytes.count {
            let (fieldNumber, wireType) = readFieldKey(bytes, &offset)
            switch (fieldNumber, wireType) {
            case (1, 0):
                trace.evaluationReason = Int(readVarint(bytes, &offset))
            default:
                skipField(bytes, &offset, wireType: wireType)
            }
        }
        return trace
    }

    // MARK: Wire format primitives

    private func readVarint(_ bytes: [UInt8], _ offset: inout Int) -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while offset < bytes.count {
            let byte = bytes[offset]
            offset += 1
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 { break }
            shift += 7
        }
        return result
    }

    private func readFieldKey(_ bytes: [UInt8], _ offset: inout Int) -> (fieldNumber: Int, wireType: Int) {
        let tag = readVarint(bytes, &offset)
        return (Int(tag >> 3), Int(tag & 0x07))
    }

    private func readLengthDelimited(_ bytes: [UInt8], _ offset: inout Int) -> [UInt8] {
        let length = Int(readVarint(bytes, &offset))
        let payload = Array(bytes[offset..<(offset + length)])
        offset += length
        return payload
    }

    private func skipField(_ bytes: [UInt8], _ offset: inout Int, wireType: Int) {
        switch wireType {
        case 0: _ = readVarint(bytes, &offset)
        case 2: _ = readLengthDelimited(bytes, &offset)
        case 1: offset += 8
        case 5: offset += 4
        default: break
        }
    }
}
// swiftlint:enable file_length
