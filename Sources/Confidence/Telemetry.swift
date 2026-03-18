import Foundation

class Telemetry {
    let sdkId: String
    let library: Library
    let libraryVersion: String
    let platform: Platform = .swift
    private let debugLogger: DebugLogger?

    private let lock = NSLock()
    private var pendingEvaluations: [EvaluationReason] = []

    init(sdkId: String, library: Library, libraryVersion: String, debugLogger: DebugLogger? = nil) {
        self.sdkId = sdkId
        self.library = library
        self.libraryVersion = libraryVersion
        self.debugLogger = debugLogger
    }

    enum Platform: Int, CustomStringConvertible {
        case unspecified = 0
        case java = 1
        case kotlin = 2
        case swift = 3
        case jsWeb = 4
        case jsServer = 5
        case python = 6
        case go = 7
        case ruby = 8
        case rust = 9
        case flutterIos = 10
        case flutterAndroid = 11

        var description: String {
            switch self {
            case .unspecified: return "UNSPECIFIED"
            case .java: return "JAVA"
            case .kotlin: return "KOTLIN"
            case .swift: return "SWIFT"
            case .jsWeb: return "JS_WEB"
            case .jsServer: return "JS_SERVER"
            case .python: return "PYTHON"
            case .go: return "GO"
            case .ruby: return "RUBY"
            case .rust: return "RUST"
            case .flutterIos: return "FLUTTER_IOS"
            case .flutterAndroid: return "FLUTTER_ANDROID"
            }
        }
    }

    enum Library: Int, CustomStringConvertible {
        case unknown = 0
        case confidence = 1
        case openFeature = 2
        case react = 3

        var description: String {
            switch self {
            case .unknown: return "UNKNOWN"
            case .confidence: return "CONFIDENCE"
            case .openFeature: return "OPEN_FEATURE"
            case .react: return "REACT"
            }
        }
    }

    enum TraceId: Int {
        case unknown = 0
        case resolveLatency = 1
        case staleFlag = 2
        case flagEvaluation = 3
    }

    enum EvaluationReason: Int, CustomStringConvertible {
        case unknown = 0
        case success = 1
        case stale = 2
        case flagNotFound = 3
        case typeMismatch = 4

        var description: String {
            switch self {
            case .unknown: return "UNKNOWN"
            case .success: return "SUCCESS"
            case .stale: return "STALE"
            case .flagNotFound: return "FLAG_NOT_FOUND"
            case .typeMismatch: return "TYPE_MISMATCH"
            }
        }
    }

    static let headerName = "X-CONFIDENCE-TELEMETRY"

    var sdk: Sdk {
        Sdk(id: sdkId, version: libraryVersion)
    }

    func trackEvaluation(reason: ResolveReason, errorCode: ErrorCode?) {
        let evalReason = Self.mapEvaluationReason(reason: reason, errorCode: errorCode)
        lock.lock()
        pendingEvaluations.append(evalReason)
        lock.unlock()
    }

    /// Returns the base64-encoded Monitoring protobuf, including any accumulated traces (which are then cleared).
    func encodedHeaderValue(for requestType: String) -> String {
        let traces = snapshotAndClearTraces()
        let monitoringBytes = encodeMonitoring(evaluationTraces: traces)
        let base64 = Data(monitoringBytes).base64EncodedString()
        let tracesDescription = traces.map { "FLAG_EVALUATION(\($0))" }.joined(separator: ", ")
        debugLogger?.logMessage(
            message: "[Telemetry] \(Self.headerName) on \(requestType) — " +
                "platform=\(platform), library=\(library), version=\(libraryVersion), " +
                "traces=[\(tracesDescription)], base64=\(base64)",
            isWarning: false)
        return base64
    }

    private func snapshotAndClearTraces() -> [EvaluationReason] {
        lock.lock()
        let snapshot = pendingEvaluations
        pendingEvaluations.removeAll()
        lock.unlock()
        return snapshot
    }

    static func mapEvaluationReason(reason: ResolveReason, errorCode: ErrorCode?) -> EvaluationReason {
        if let errorCode = errorCode {
            switch errorCode {
            case .flagNotFound:
                return .flagNotFound
            case .typeMismatch:
                return .typeMismatch
            default:
                return .unknown
            }
        }
        switch reason {
        case .match, .noSegmentMatch, .noTreatmentMatch, .archived:
            return .success
        case .stale:
            return .stale
        default:
            return .unknown
        }
    }
}

// MARK: Protobuf wire-format encoding for the Monitoring message.
// Matches confidence/telemetry.proto without requiring a SwiftProtobuf dependency.
extension Telemetry {
    private func encodeMonitoring(evaluationTraces: [EvaluationReason]) -> [UInt8] {
        var bytes: [UInt8] = []

        let libraryTracesPayload = encodeLibraryTraces(evaluationTraces: evaluationTraces)
        bytes.append(contentsOf: fieldKey(fieldNumber: 1, wireType: .lengthDelimited))
        bytes.append(contentsOf: encodeVarint(UInt64(libraryTracesPayload.count)))
        bytes.append(contentsOf: libraryTracesPayload)

        if platform.rawValue != 0 {
            bytes.append(contentsOf: fieldKey(fieldNumber: 2, wireType: .varint))
            bytes.append(contentsOf: encodeVarint(UInt64(platform.rawValue)))
        }

        return bytes
    }

    private func encodeLibraryTraces(evaluationTraces: [EvaluationReason]) -> [UInt8] {
        var bytes: [UInt8] = []

        if library.rawValue != 0 {
            bytes.append(contentsOf: fieldKey(fieldNumber: 1, wireType: .varint))
            bytes.append(contentsOf: encodeVarint(UInt64(library.rawValue)))
        }

        let versionBytes = [UInt8](libraryVersion.utf8)
        bytes.append(contentsOf: fieldKey(fieldNumber: 2, wireType: .lengthDelimited))
        bytes.append(contentsOf: encodeVarint(UInt64(versionBytes.count)))
        bytes.append(contentsOf: versionBytes)

        for evalReason in evaluationTraces {
            let traceBytes = encodeEvaluationTrace(reason: evalReason)
            bytes.append(contentsOf: fieldKey(fieldNumber: 3, wireType: .lengthDelimited))
            bytes.append(contentsOf: encodeVarint(UInt64(traceBytes.count)))
            bytes.append(contentsOf: traceBytes)
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
