import Foundation

class Telemetry: @unchecked Sendable {
    let sdkId: String
    let library: Library
    let libraryVersion: String
    let platform: Platform = .swift
    private let debugLogger: DebugLogger?

    private let lock = NSLock()
    private var pendingEvaluations: [EvaluationReason] = []
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
        case unknown = 0
        case success = 1
        case stale = 2
        case flagNotFound = 3
        case typeMismatch = 4
        case error = 5

        var description: String {
            switch self {
            case .unknown: return "UNKNOWN"
            case .success: return "SUCCESS"
            case .stale: return "STALE"
            case .flagNotFound: return "FLAG_NOT_FOUND"
            case .typeMismatch: return "TYPE_MISMATCH"
            case .error: return "ERROR"
            }
        }
    }

    static let headerName = "X-CONFIDENCE-TELEMETRY"

    var sdk: Sdk {
        Sdk(id: sdkId, version: libraryVersion)
    }

    func trackEvaluation(reason: ResolveReason, errorCode: ErrorCode?) {
        let evalReason = Self.mapEvaluationReason(reason: reason, errorCode: errorCode)
        lock.withLock {
            pendingEvaluations.append(evalReason)
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

    private func snapshotAndClearTraces() -> ([EvaluationReason], [ResolveTrace]) {
        lock.withLock {
            let evals = pendingEvaluations
            let resolves = pendingResolveTraces
            pendingEvaluations.removeAll()
            pendingResolveTraces.removeAll()
            return (evals, resolves)
        }
    }

    static func mapEvaluationReason(reason: ResolveReason, errorCode: ErrorCode?) -> EvaluationReason {
        if let errorCode = errorCode {
            switch errorCode {
            case .flagNotFound:
                return .flagNotFound
            case .typeMismatch:
                return .typeMismatch
            default:
                return .error
            }
        }
        switch reason {
        case .match, .noSegmentMatch, .noTreatmentMatch:
            return .success
        case .stale:
            return .stale
        case .archived, .error, .targetingKeyError:
            return .error
        default:
            return .unknown
        }
    }
}

// MARK: Protobuf wire-format encoding for the Monitoring message.
// Matches confidence/telemetry.proto without requiring a SwiftProtobuf dependency.
extension Telemetry {
    private func encodeMonitoring(
        evaluationTraces: [EvaluationReason],
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
        evaluationTraces: [EvaluationReason],
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
        for evalReason in evaluationTraces {
            let traceBytes = encodeEvaluationTrace(reason: evalReason)
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

    // Trace { id = TRACE_ID_FLAG_EVALUATION, evaluation_trace = EvaluationTrace { evaluation_reason } }
    private func encodeEvaluationTrace(reason: EvaluationReason) -> [UInt8] {
        var bytes: [UInt8] = []

        bytes.append(contentsOf: fieldKey(fieldNumber: 1, wireType: .varint))
        bytes.append(contentsOf: encodeVarint(UInt64(TraceId.flagEvaluation.rawValue)))

        let evalPayload = encodeEvaluationTracePayload(reason: reason)
        if !evalPayload.isEmpty {
            bytes.append(contentsOf: fieldKey(fieldNumber: 5, wireType: .lengthDelimited))
            bytes.append(contentsOf: encodeVarint(UInt64(evalPayload.count)))
            bytes.append(contentsOf: evalPayload)
        }

        return bytes
    }

    // EvaluationTrace { evaluation_reason }
    private func encodeEvaluationTracePayload(reason: EvaluationReason) -> [UInt8] {
        var bytes: [UInt8] = []
        if reason.rawValue != 0 {
            bytes.append(contentsOf: fieldKey(fieldNumber: 1, wireType: .varint))
            bytes.append(contentsOf: encodeVarint(UInt64(reason.rawValue)))
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
