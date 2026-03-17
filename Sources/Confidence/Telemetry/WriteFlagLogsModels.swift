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
}

struct WriteFlagLogsResponse: Codable {}
