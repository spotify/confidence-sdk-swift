import Foundation

public struct GrpcStatusCode {
    private let _rawValue: UInt8

    public var rawValue: Int {
        return Int(self._rawValue)
    }

    private init(_ code: UInt8) {
        self._rawValue = code
    }

    // swiftlint:disable:next identifier_name
    public static let ok = GrpcStatusCode(0)
    public static let cancelled = GrpcStatusCode(1)
    public static let unknown = GrpcStatusCode(2)
    public static let invalidArgument = GrpcStatusCode(3)
    public static let deadlineExceeded = GrpcStatusCode(4)
    public static let notFound = GrpcStatusCode(5)
    public static let alreadyExists = GrpcStatusCode(6)
    public static let permissionDenied = GrpcStatusCode(7)
    public static let resourceExhausted = GrpcStatusCode(8)
    public static let failedPrecondition = GrpcStatusCode(9)
    public static let aborted = GrpcStatusCode(10)
    public static let outOfRange = GrpcStatusCode(11)
    public static let unimplemented = GrpcStatusCode(12)
    public static let internalError = GrpcStatusCode(13)
    public static let unavailable = GrpcStatusCode(14)
    public static let dataLoss = GrpcStatusCode(15)
    public static let unauthenticated = GrpcStatusCode(16)
}
