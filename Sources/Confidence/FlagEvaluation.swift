import Foundation

public struct Evaluation<T> {
    public let value: T
    public let variant: String? = nil
    public let reason: ResolveReason
    public let errorCode: ErrorCode? = nil
    public let errorMessage: String? = nil
}

public enum ErrorCode {
}

struct FlagResolution: Encodable, Decodable {
    let context: ConfidenceStruct
    let flags: [ResolvedValue]
    let resolveToken: String
    static let EMPTY = FlagResolution(context: [:], flags: [], resolveToken: "")
}
