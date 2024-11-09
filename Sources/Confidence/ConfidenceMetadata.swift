import Foundation

struct ConfidenceMetadata {
    private static let sdkName: String = "SDK_ID_SWIFT_CONFIDENCE"
    private static let sdkId: Int = 13 // TODO enstablish cross-language identifiers

    public var id: Int
    public var name: String
    public var version: String

    public static let defaultMetadata = ConfidenceMetadata(
        id: sdkId,
        name: sdkName,
        version: "1.0.1") // x-release-please-version
}
