import Foundation

struct WriteFlagLogsRequest: Codable {
    var flagAssigned: [FlagAssignedEvent]?
    var telemetryData: TelemetryData?
}

struct FlagAssignedEvent: Codable {
    var resolveId: String
    var clientInfo: ClientInfo
    var flags: [AppliedFlag]
}

struct AppliedFlag: Codable {
    var flag: String
    var applyTime: String
}

struct ClientInfo: Codable {
    var sdk: SdkInfo
}

struct SdkInfo: Codable {
    var id: String
    var version: String
}

struct TelemetryData: Codable {
    var sdk: SdkInfo?
    var resolveRate: [ResolveRateRecord]?
    var clientErrorRate: [ClientErrorRateRecord]?
}

struct ResolveRateRecord: Codable, Equatable {
    var count: UInt32
    var reason: String
}

struct ClientErrorRateRecord: Codable, Equatable {
    var count: UInt32
    var errorCode: String
}

struct WriteFlagLogsResponse: Codable {}
