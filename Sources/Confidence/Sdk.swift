import Foundation

public struct Sdk: Codable {
    public init(id: String?, version: String?) {
        self.id = id ?? "SDK_ID_SWIFT_PROVIDER"
        self.version = version ?? "unknown"
    }

    var id: String
    var version: String
}
