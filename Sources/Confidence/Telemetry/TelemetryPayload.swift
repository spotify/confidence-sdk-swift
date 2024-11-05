import Foundation

struct TelemetryPayload: Encodable {
    var libraryId: Int
    var libraryVersion: String
    var countTraces: [CountTrace]
    var durationsTraces: [DurationsTrace]
}

struct CountTrace: Encodable {
    var traceId: TraceId
    var count: Int
}

struct DurationsTrace: Encodable {
    var traceId: TraceId
    var millisDuration: [Int]
}

enum TraceId: Int, Encodable {
    case typeMismatch = 1
    case staleAccess = 2
}
