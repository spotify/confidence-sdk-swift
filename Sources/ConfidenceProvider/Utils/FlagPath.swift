import Foundation
import OpenFeature

public struct FlagPath {
    var flag: String
    var path: [String]

    public static func getPath(for path: String) throws -> FlagPath {
        let parts = path.components(separatedBy: ".")

        guard let flag = parts.first else {
            throw OpenFeatureError.generalError(message: "Flag value key is empty")
        }

        return .init(flag: flag, path: Array(parts.suffix(from: 1)))
    }
}
