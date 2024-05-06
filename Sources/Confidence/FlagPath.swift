import Foundation

public struct FlagPath {
    var flag: String
    var path: [String]

    public static func getPath(for path: String) throws -> FlagPath {
        let parts = path.components(separatedBy: ".")

        guard let flag = parts.first else {
            throw ConfidenceError.internalError(message: "Flag value key is empty")
        }

        return .init(flag: flag, path: Array(parts.suffix(from: 1)))
    }
}
