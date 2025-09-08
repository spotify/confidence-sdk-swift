import Foundation

protocol ConfidenceClient {
    // Returns true if the batch has been correctly processed by the backend
    func upload(events: [NetworkEvent]) async throws -> Bool
}

protocol ConfidenceResolveClient {
    // Async
    func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult
}

struct ResolvedValue: Codable, Equatable {
    var variant: String?
    var value: ConfidenceValue?
    var flag: String
    var resolveReason: ResolveReason
    var shouldApply: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        variant = try container.decodeIfPresent(String.self, forKey: .variant)
        value = try container.decodeIfPresent(ConfidenceValue.self, forKey: .value)
        flag = try container.decode(String.self, forKey: .flag)
        resolveReason = try container.decode(ResolveReason.self, forKey: .resolveReason)

        // Default shouldApply to true for backward compatibility when field is missing
        shouldApply = try container.decodeIfPresent(Bool.self, forKey: .shouldApply) ?? true
    }

    init(
        variant: String? = nil,
        value: ConfidenceValue? = nil,
        flag: String,
        resolveReason: ResolveReason,
        shouldApply: Bool = true
        ) {
        self.variant = variant
        self.value = value
        self.flag = flag
        self.resolveReason = resolveReason
        self.shouldApply = shouldApply
    }

    private enum CodingKeys: String, CodingKey {
        case variant, value, flag, resolveReason, shouldApply
    }
}

public struct ResolvesResult: Codable, Equatable {
    var resolvedValues: [ResolvedValue]
    var resolveToken: String?
}
