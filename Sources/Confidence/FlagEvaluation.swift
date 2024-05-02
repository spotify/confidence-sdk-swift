import Foundation
import Common

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

extension FlagResolution {
    func evaluate<T>(flagName: String, defaultValue: T, context: ConfidenceStruct, flagApplier: FlagApplier) throws -> Evaluation<T> {
        throw ConfidenceError.internalError(message: "")
    }
}
