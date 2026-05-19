// NOTE(unit-local experiment): EXPERIMENTAL. A ConfidenceResolveClient that
// resolves flags via the embedded Confidence WASM resolver instead of hitting
// the remote backend. Slices are fetched on demand from a local slice server
// (see openfeature-provider/swift/.. and unit-local-server in the
// confidence-resolver repo).
//
// Not thread-safe across resolve calls; relies on NSLock around the underlying
// WASM instance. Will change shape before any productionisation.

import ConfidenceLocalResolver
import Foundation
import SwiftProtobuf

public actor LocalConfidenceResolveClient: ConfidenceResolveClient {
    private let clientSecret: String
    private let sliceClient: SliceClient
    private let resolver: LocalResolver
    private let accountId: String
    private let stateFileHash: String
    private let randomizationUnitFields: [String]
    private var lastUnit: String?

    /// Bootstraps the local resolver by fetching account configuration from the
    /// local slice server and instantiating the WASM module.
    public static func bootstrap(clientSecret: String, serverURL: URL) async throws -> LocalConfidenceResolveClient {
        let sliceClient = SliceClient(baseURL: serverURL)
        let config = try await sliceClient.accountConfig()
        let resolver = try LocalResolver()
        return LocalConfidenceResolveClient(
            clientSecret: clientSecret,
            sliceClient: sliceClient,
            resolver: resolver,
            accountId: config.accountId,
            stateFileHash: config.stateFileHash,
            randomizationUnitFields: config.randomizationUnitFields
        )
    }

    private init(
        clientSecret: String,
        sliceClient: SliceClient,
        resolver: LocalResolver,
        accountId: String,
        stateFileHash: String,
        randomizationUnitFields: [String]
    ) {
        self.clientSecret = clientSecret
        self.sliceClient = sliceClient
        self.resolver = resolver
        self.accountId = accountId
        self.stateFileHash = stateFileHash
        self.randomizationUnitFields = randomizationUnitFields
    }

    public func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
        let unit = try extractUnit(from: ctx)
        if lastUnit != unit {
            let slice = try await sliceClient.fetchSlice(stateFileHash: stateFileHash, unit: unit)
            try resolver.setResolverState(slice.bytes, accountId: accountId)
            lastUnit = unit
        }
        let pbCtx = LocalProtoConverters.toProtoStruct(ctx)
        let response = try resolver.resolveFlags(
            clientSecret: clientSecret,
            evaluationContext: pbCtx,
            apply: true
        )
        let resolvedValues = response.resolvedFlags.map { LocalProtoConverters.convertResolvedFlag($0) }
        return ResolvesResult(resolvedValues: resolvedValues, resolveToken: nil)
    }

    private func extractUnit(from ctx: ConfidenceStruct) throws -> String {
        for field in randomizationUnitFields {
            if let value = ctx[field]?.asString(), !value.isEmpty {
                return value
            }
        }
        throw LocalResolveError.missingRandomizationUnit(fields: randomizationUnitFields)
    }
}

public enum LocalResolveError: Swift.Error, CustomStringConvertible {
    case missingRandomizationUnit(fields: [String])

    public var description: String {
        switch self {
        case .missingRandomizationUnit(let fields):
            return "Evaluation context must contain a non-empty string value for one of: \(fields)"
        }
    }
}

// MARK: - Proto ↔ SDK value conversions

enum LocalProtoConverters {
    static func toProtoStruct(_ ctx: ConfidenceStruct) -> Google_Protobuf_Struct {
        var result = Google_Protobuf_Struct()
        result.fields = ctx.mapValues { toProtoValue($0) }
        return result
    }

    static func toProtoValue(_ value: ConfidenceValue) -> Google_Protobuf_Value {
        switch value.type() {
        case .boolean:
            return .with { $0.boolValue = value.asBoolean() ?? false }
        case .string:
            return .with { $0.stringValue = value.asString() ?? "" }
        case .integer:
            return .with { $0.numberValue = Double(value.asInteger() ?? 0) }
        case .double:
            return .with { $0.numberValue = value.asDouble() ?? 0 }
        case .date:
            let formatter = ISO8601DateFormatter()
            formatter.timeZone = TimeZone.current
            formatter.formatOptions = [.withFullDate]
            if let components = value.asDateComponents(), let date = Calendar.current.date(from: components) {
                return .with { $0.stringValue = formatter.string(from: date) }
            }
            return .with { $0.stringValue = "" }
        case .timestamp:
            let formatter = ISO8601DateFormatter()
            formatter.timeZone = TimeZone(identifier: "UTC")
            if let date = value.asDate() {
                return .with { $0.stringValue = formatter.string(from: date) }
            }
            return .with { $0.stringValue = "" }
        case .list:
            let elements = (value.asList() ?? []).map { toProtoValue($0) }
            return .with { $0.listValue = Google_Protobuf_ListValue.with { $0.values = elements } }
        case .structure:
            let inner = (value.asStructure() ?? [:]).mapValues { toProtoValue($0) }
            var s = Google_Protobuf_Struct()
            s.fields = inner
            return .with { $0.structValue = s }
        case .null:
            return .with { $0.nullValue = .nullValue }
        }
    }

    static func convertResolvedFlag(_ pb: Confidence_Flags_Resolver_V1_ResolvedFlag) -> ResolvedValue {
        let flagName = stripFlagsPrefix(pb.flag)
        if pb.value.fields.isEmpty {
            return ResolvedValue(
                value: nil,
                flag: flagName,
                resolveReason: mapReason(pb.reason),
                shouldApply: true
            )
        }
        let cValue = ConfidenceValue(from: .structure(toNetworkStruct(pb.value)))
        return ResolvedValue(
            variant: pb.variant.isEmpty ? nil : pb.variant,
            value: cValue,
            flag: flagName,
            resolveReason: mapReason(pb.reason),
            shouldApply: true
        )
    }

    private static func stripFlagsPrefix(_ raw: String) -> String {
        if raw.hasPrefix("flags/") {
            return String(raw.dropFirst("flags/".count))
        }
        return raw
    }

    private static func toNetworkStruct(_ pb: Google_Protobuf_Struct) -> NetworkStruct {
        NetworkStruct(fields: pb.fields.mapValues { toNetworkValue($0) })
    }

    private static func toNetworkValue(_ pb: Google_Protobuf_Value) -> NetworkValue {
        switch pb.kind {
        case .stringValue(let s): return .string(s)
        case .numberValue(let n): return .number(n)
        case .boolValue(let b): return .boolean(b)
        case .nullValue: return .null
        case .listValue(let list): return .list(list.values.map(toNetworkValue))
        case .structValue(let s): return .structure(toNetworkStruct(s))
        case nil: return .null
        }
    }

    private static func mapReason(_ pb: Confidence_Flags_Resolver_V1_ResolveReason) -> ResolveReason {
        switch pb {
        case .unspecified: return .unspecified
        case .match: return .match
        case .noSegmentMatch: return .noSegmentMatch
        case .noTreatmentMatch: return .noTreatmentMatch
        case .flagArchived: return .archived
        case .targetingKeyError: return .targetingKeyError
        case .error: return .error
        default: return .unknown
        }
    }
}
