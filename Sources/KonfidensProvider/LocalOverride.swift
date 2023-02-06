import Foundation
import OpenFeature

public enum LocalOverride {
    case flag(name: String, variant: String, value: [String: Value])
    case field(path: String, variant: String, value: Value)

    func key() -> String {
        switch self {
        case .flag(let name, _, _):
            return name
        case .field(let path, _, _):
            return path
        }
    }
}
