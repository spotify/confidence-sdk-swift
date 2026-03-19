import Foundation

class Telemetry: @unchecked Sendable {
    let sdkId: String
    private(set) var library: Library
    let libraryVersion: String
    let platform: Platform = .swift
    private let debugLogger: DebugLogger?

    private let lock = NSLock()
    private var pendingEvaluations: [(reason: EvaluationReason, errorCode: EvaluationErrorCode)] = []
    private var pendingResolveTraces: [ResolveTrace] = []

    init(sdkId: String, library: Library, libraryVersion: String, debugLogger: DebugLogger? = nil) {
        self.sdkId = sdkId
        self.library = library
        self.libraryVersion = libraryVersion
        self.debugLogger = debugLogger
    }

    enum Platform: Int {
        case swift = 3
    }

    enum Library: Int {
        case confidence = 1
        case openFeature = 2
    }

    enum TraceId: Int {
        case resolveLatency = 1
        case flagEvaluation = 3
    }

    enum RequestStatus: Int, CustomStringConvertible {
        case unspecified = 0
        case success = 1
        case error = 2
        case timeout = 3

        var description: String {
            switch self {
            case .unspecified: return "UNSPECIFIED"
            case .success: return "SUCCESS"
            case .error: return "ERROR"
            case .timeout: return "TIMEOUT"
            }
        }
    }

    struct ResolveTrace {
        let durationMs: UInt64
        let status: RequestStatus
    }

    enum EvaluationReason: Int, CustomStringConvertible {
        case unspecified = 0
        case targetingMatch = 1
        case `default` = 2
        case stale = 3
        case disabled = 4
        case cached = 5
        case `static` = 6
        case split = 7
        case error = 8

        var description: String {
            switch self {
            case .unspecified: return "UNSPECIFIED"
            case .targetingMatch: return "TARGETING_MATCH"
            case .default: return "DEFAULT"
            case .stale: return "STALE"
            case .disabled: return "DISABLED"
            case .cached: return "CACHED"
            case .static: return "STATIC"
            case .split: return "SPLIT"
            case .error: return "ERROR"
            }
        }
    }

    enum EvaluationErrorCode: Int, CustomStringConvertible {
        case unspecified = 0
        case providerNotReady = 1
        case flagNotFound = 2
        case parseError = 3
        case typeMismatch = 4
        case targetingKeyMissing = 5
        case invalidContext = 6
        case providerFatal = 7
        case general = 8

        var description: String {
            switch self {
            case .unspecified: return "UNSPECIFIED"
            case .providerNotReady: return "PROVIDER_NOT_READY"
            case .flagNotFound: return "FLAG_NOT_FOUND"
            case .parseError: return "PARSE_ERROR"
            case .typeMismatch: return "TYPE_MISMATCH"
            case .targetingKeyMissing: return "TARGETING_KEY_MISSING"
            case .invalidContext: return "INVALID_CONTEXT"
            case .providerFatal: return "PROVIDER_FATAL"
            case .general: return "GENERAL"
            }
        }
    }

    static let headerName = "X-CONFIDENCE-TELEMETRY"

    var sdk: Sdk {
        Sdk(id: sdkId, version: libraryVersion)
    }

    func trackEvaluation(reason: ResolveReason, errorCode: ErrorCode?) {
        let mapped = Self.mapEvaluationReason(reason: reason, errorCode: errorCode)
        lock.withLock {
            pendingEvaluations.append(mapped)
        }
    }

    func trackResolveLatency(durationMs: UInt64, status: RequestStatus) {
        lock.withLock {
            pendingResolveTraces.append(ResolveTrace(durationMs: durationMs, status: status))
        }
    }

    /// Returns the base64-encoded Monitoring protobuf, including any accumulated traces (which are then cleared).
    func encodedHeaderValue() -> String {
        let (evalTraces, resolveTraces) = snapshotAndClearTraces()
        let monitoringBytes = encodeMonitoring(
            evaluationTraces: evalTraces,
            resolveTraces: resolveTraces
        )
        return Data(monitoringBytes).base64EncodedString()
    }

    private func snapshotAndClearTraces() -> ([(reason: EvaluationReason, errorCode: EvaluationErrorCode)], [ResolveTrace]) {
        lock.withLock {
            let evals = pendingEvaluations
            let resolves = pendingResolveTraces
            pendingEvaluations.removeAll()
            pendingResolveTraces.removeAll()
            return (evals, resolves)
        }
    }

    static func mapEvaluationReason(
        reason: ResolveReason, errorCode: ErrorCode?
    ) -> (reason: EvaluationReason, errorCode: EvaluationErrorCode) {
        if let errorCode = errorCode {
            let mappedError: EvaluationErrorCode
            switch errorCode {
            case .flagNotFound:
                mappedError = .flagNotFound
            case .typeMismatch:
                mappedError = .typeMismatch
            case .parseError:
                mappedError = .parseError
            case .invalidContext:
                mappedError = .invalidContext
            case .providerNotReady:
                mappedError = .providerNotReady
            default:
                mappedError = .general
            }
            return (.error, mappedError)
        }
        switch reason {
        case .match:
            return (.targetingMatch, .unspecified)
        case .noSegmentMatch, .noTreatmentMatch:
            return (.default, .unspecified)
        case .stale:
            return (.stale, .unspecified)
        case .archived:
            return (.disabled, .unspecified)
        case .targetingKeyError:
            return (.error, .targetingKeyMissing)
        case .error:
            return (.error, .general)
        default:
            return (.unspecified, .unspecified)
        }
    }
}

// MARK: Protobuf wire-format encoding for the Monitoring message.
// Matches confidence/telemetry.proto without requiring a SwiftProtobuf dependency.
extension Telemetry {
    private func encodeMonitoring(
        evaluationTraces: [(reason: EvaluationReason, errorCode: EvaluationErrorCode)],
        resolveTraces: [ResolveTrace]
    ) -> [UInt8] {
        var bytes: [UInt8] = []

        let libraryTracesPayload = encodeLibraryTraces(
            evaluationTraces: evaluationTraces,
            resolveTraces: resolveTraces
        )
        bytes.append(contentsOf: fieldKey(fieldNumber: 1, wireType: .lengthDelimited))
        bytes.append(contentsOf: encodeVarint(UInt64(libraryTracesPayload.count)))
        bytes.append(contentsOf: libraryTracesPayload)

        if platform.rawValue != 0 {
            bytes.append(contentsOf: fieldKey(fieldNumber: 2, wireType: .varint))
            bytes.append(contentsOf: encodeVarint(UInt64(platform.rawValue)))
        }

        return bytes
    }

    private func encodeLibraryTraces(
        evaluationTraces: [(reason: EvaluationReason, errorCode: EvaluationErrorCode)],
        resolveTraces: [ResolveTrace]
    ) -> [UInt8] {
        var bytes: [UInt8] = []

        if library.rawValue != 0 {
            bytes.append(contentsOf: fieldKey(fieldNumber: 1, wireType: .varint))
            bytes.append(contentsOf: encodeVarint(UInt64(library.rawValue)))
        }

        let versionBytes = [UInt8](libraryVersion.utf8)
        bytes.append(contentsOf: fieldKey(fieldNumber: 2, wireType: .lengthDelimited))
        bytes.append(contentsOf: encodeVarint(UInt64(versionBytes.count)))
        bytes.append(contentsOf: versionBytes)

        // Resolve latency traces (field 3: repeated Trace)
        for trace in resolveTraces {
            let traceBytes = encodeResolveTrace(trace)
            bytes.append(contentsOf: fieldKey(fieldNumber: 3, wireType: .lengthDelimited))
            bytes.append(contentsOf: encodeVarint(UInt64(traceBytes.count)))
            bytes.append(contentsOf: traceBytes)
        }

        // Evaluation traces (field 3: repeated Trace)
        for eval in evaluationTraces {
            let traceBytes = encodeEvaluationTrace(reason: eval.reason, errorCode: eval.errorCode)
            bytes.append(contentsOf: fieldKey(fieldNumber: 3, wireType: .lengthDelimited))
            bytes.append(contentsOf: encodeVarint(UInt64(traceBytes.count)))
            bytes.append(contentsOf: traceBytes)
        }

        return bytes
    }

    // Trace { id = TRACE_ID_RESOLVE_LATENCY, request_trace = RequestTrace { ms, status } }
    private func encodeResolveTrace(_ trace: ResolveTrace) -> [UInt8] {
        var bytes: [UInt8] = []

        // field 1: TraceId id = TRACE_ID_RESOLVE_LATENCY
        bytes.append(contentsOf: fieldKey(fieldNumber: 1, wireType: .varint))
        bytes.append(contentsOf: encodeVarint(UInt64(TraceId.resolveLatency.rawValue)))

        // field 3: RequestTrace request_trace (oneof traceData)
        let requestTracePayload = encodeRequestTrace(trace)
        bytes.append(contentsOf: fieldKey(fieldNumber: 3, wireType: .lengthDelimited))
        bytes.append(contentsOf: encodeVarint(UInt64(requestTracePayload.count)))
        bytes.append(contentsOf: requestTracePayload)

        return bytes
    }

    // RequestTrace { millisecond_duration, status }
    private func encodeRequestTrace(_ trace: ResolveTrace) -> [UInt8] {
        var bytes: [UInt8] = []

        if trace.durationMs != 0 {
            bytes.append(contentsOf: fieldKey(fieldNumber: 1, wireType: .varint))
            bytes.append(contentsOf: encodeVarint(trace.durationMs))
        }

        if trace.status.rawValue != 0 {
            bytes.append(contentsOf: fieldKey(fieldNumber: 2, wireType: .varint))
            bytes.append(contentsOf: encodeVarint(UInt64(trace.status.rawValue)))
        }

        return bytes
    }

    // Trace { id = TRACE_ID_FLAG_EVALUATION, evaluation_trace = EvaluationTrace { reason, error_code } }
    private func encodeEvaluationTrace(reason: EvaluationReason, errorCode: EvaluationErrorCode) -> [UInt8] {
        var bytes: [UInt8] = []

        bytes.append(contentsOf: fieldKey(fieldNumber: 1, wireType: .varint))
        bytes.append(contentsOf: encodeVarint(UInt64(TraceId.flagEvaluation.rawValue)))

        let evalPayload = encodeEvaluationTracePayload(reason: reason, errorCode: errorCode)
        if !evalPayload.isEmpty {
            bytes.append(contentsOf: fieldKey(fieldNumber: 5, wireType: .lengthDelimited))
            bytes.append(contentsOf: encodeVarint(UInt64(evalPayload.count)))
            bytes.append(contentsOf: evalPayload)
        }

        return bytes
    }

    // EvaluationTrace { reason, error_code }
    private func encodeEvaluationTracePayload(reason: EvaluationReason, errorCode: EvaluationErrorCode) -> [UInt8] {
        var bytes: [UInt8] = []
        if reason.rawValue != 0 {
            bytes.append(contentsOf: fieldKey(fieldNumber: 1, wireType: .varint))
            bytes.append(contentsOf: encodeVarint(UInt64(reason.rawValue)))
        }
        if errorCode.rawValue != 0 {
            bytes.append(contentsOf: fieldKey(fieldNumber: 2, wireType: .varint))
            bytes.append(contentsOf: encodeVarint(UInt64(errorCode.rawValue)))
        }
        return bytes
    }

    private enum WireType: UInt8 {
        case varint = 0
        case lengthDelimited = 2
    }

    private func fieldKey(fieldNumber: UInt32, wireType: WireType) -> [UInt8] {
        encodeVarint(UInt64(fieldNumber << 3 | UInt32(wireType.rawValue)))
    }

    private func encodeVarint(_ value: UInt64) -> [UInt8] {
        var bytes: [UInt8] = []
        var val = value
        while val > 0x7F {
            bytes.append(UInt8(val & 0x7F) | 0x80)
            val >>= 7
        }
        bytes.append(UInt8(val))
        return bytes
    }
}
