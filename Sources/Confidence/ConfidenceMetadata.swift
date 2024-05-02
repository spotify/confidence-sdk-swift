import Foundation

public struct ConfidenceMetadata {
    public var name: String? = "SDK_ID_SWIFT_PROVIDER"
    public var version: String?

    public init(name: String? = nil, version: String? = nil) {
        self.name = name
        self.version = version
    }
}
