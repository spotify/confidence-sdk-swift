import Foundation
import OpenFeature

public class RemoteConfidenceClient: ConfidenceClient {
    private let targetingKey = "targeting_key"
    private let flagApplier: FlagApplier
    private var options: ConfidenceClientOptions

    private var httpClient: HttpClient
    private var applyOnResolve: Bool

    init(
        options: ConfidenceClientOptions,
        session: URLSession? = nil,
        applyOnResolve: Bool,
        flagApplier: FlagApplier
    ) {
        self.options = options
        self.httpClient = NetworkClient(session: session, region: options.region)
        self.flagApplier = flagApplier
        self.applyOnResolve = applyOnResolve
    }

    public func resolve(flags: [String], ctx: EvaluationContext) throws -> ResolvesResult {
        let request = ResolveFlagsRequest(
            flags: flags.map { "flags/\($0)" },
            evaluationContext: try getEvaluationContextStruct(ctx: ctx),
            clientSecret: options.credentials.getSecret(),
            apply: applyOnResolve)

        do {
            let result = try self.httpClient.post(
                path: ":resolve", data: request, resultType: ResolveFlagsResponse.self)
            guard result.response.status == .ok else {
                throw result.response.mapStatusToError(error: result.decodedError)
            }

            guard let response = result.decodedData else {
                throw OpenFeatureError.parseError(message: "Unable to parse request response")
            }

            let resolvedValues = try response.resolvedFlags.map { resolvedFlag in
                try convert(resolvedFlag: resolvedFlag, ctx: ctx)
            }
            return ResolvesResult(resolvedValues: resolvedValues, resolveToken: response.resolveToken)
        } catch let error {
            throw handleError(error: error)
        }
    }

    public func resolve(ctx: EvaluationContext) throws -> ResolvesResult {
        return try resolve(flags: [], ctx: ctx)
    }

    public func resolve(flag: String, ctx: EvaluationContext) throws -> ResolveResult {
        let resolveResult = try resolve(flags: [flag], ctx: ctx)
        guard let resolvedValue = resolveResult.resolvedValues.first else {
            throw OpenFeatureError.flagNotFoundError(key: flag)
        }
        return ResolveResult(resolvedValue: resolvedValue, resolveToken: resolveResult.resolveToken)
    }

    private func convert(resolvedFlag: ResolvedFlag, ctx: EvaluationContext) throws -> ResolvedValue {
        guard let responseFlagSchema = resolvedFlag.flagSchema,
            let responseValue = resolvedFlag.value,
            !responseValue.fields.isEmpty
        else {
            return ResolvedValue(
                value: nil,
                flag: try displayName(resolvedFlag: resolvedFlag),
                resolveReason: convert(resolveReason: resolvedFlag.reason))
        }

        let value = try TypeMapper.from(object: responseValue, schema: responseFlagSchema)
        let variant = resolvedFlag.variant.isEmpty ? nil : resolvedFlag.variant

        return ResolvedValue(
            variant: variant,
            value: value,
            flag: try displayName(resolvedFlag: resolvedFlag),
            resolveReason: convert(resolveReason: resolvedFlag.reason))
    }

    private func getEvaluationContextStruct(ctx: EvaluationContext) throws -> Struct {
        var evaluationContext = TypeMapper.from(value: ctx)
        evaluationContext.fields[targetingKey] = .string(ctx.getTargetingKey())
        return evaluationContext
    }

    private func handleError(error: Error) -> Error {
        if error is ConfidenceError || error is OpenFeatureError {
            return error
        } else {
            return ConfidenceError.grpcError(message: "\(error)")
        }
    }

    private func convert(resolveReason: ResolveReason) -> ResolvedValue.Reason {
        switch resolveReason {
        case .error, .unknown, .unspecified: return .generalError
        case .noSegmentMatch, .noTreatmentMatch: return .noMatch
        case .match: return .match
        case .archived: return .disabled
        case .targetngKeyError: return .targetingKeyError
        }
    }
}

struct ResolveFlagsRequest: Codable {
    var flags: [String]
    var evaluationContext: Struct
    var clientSecret: String
    var apply: Bool
}

struct ResolveFlagsResponse: Codable {
    var resolvedFlags: [ResolvedFlag]
    var resolveToken: String?
}

struct ResolvedFlag: Codable {
    var flag: String
    var value: Struct? = Struct(fields: [:])
    var variant: String = ""
    var flagSchema: StructFlagSchema? = StructFlagSchema(schema: [:])
    var reason: ResolveReason
}

enum ResolveReason: String, Codable, CaseIterableDefaultsLast {
    case unspecified = "RESOLVE_REASON_UNSPECIFIED"
    case match = "RESOLVE_REASON_MATCH"
    case noSegmentMatch = "RESOLVE_REASON_NO_SEGMENT_MATCH"
    case noTreatmentMatch = "RESOLVE_REASON_NO_TREATMENT_MATCH"
    case archived = "RESOLVE_REASON_FLAG_ARCHIVED"
    case targetngKeyError = "RESOLVE_REASON_TARGETING_KEY_ERROR"
    case error = "RESOLVE_REASON_ERROR"
    case unknown
}

struct AppliedFlagRequestItem: Codable {
    let flag: String
    let applyTime: String

    init(flag: String, applyTime: Date) {
        self.flag = "flags/\(flag)"
        self.applyTime = Date.backport.toISOString(date: applyTime)
    }
}

struct ApplyFlagsRequest: Codable {
    var flags: [AppliedFlagRequestItem]
    var sendTime: String
    var clientSecret: String
    var resolveToken: String
}

struct ApplyFlagsResponse: Codable {
}

public struct ConfidenceClientOptions {
    public var credentials: ConfidenceClientCredentials
    public var timeout: TimeInterval
    public var region: ConfidenceRegion

    public init(
        credentials: ConfidenceClientCredentials, timeout: TimeInterval? = nil, region: ConfidenceRegion? = nil
    ) {
        self.credentials = credentials
        self.timeout = timeout ?? 10.0
        self.region = region ?? .europe
    }
}

public enum ConfidenceClientCredentials {
    case clientSecret(secret: String)

    public func getSecret() -> String {
        switch self {
        case .clientSecret(let secret):
            return secret
        }
    }
}

public enum ConfidenceRegion: String {
    case europe = "eu"
    case usa = "us"
}

private func displayName(resolvedFlag: ResolvedFlag) throws -> String {
    let flagNameComponents = resolvedFlag.flag.components(separatedBy: "/")
    if flagNameComponents.count <= 1 || flagNameComponents[0] != "flags" {
        throw ConfidenceError.internalError(message: "Unxpected flag name: \(resolvedFlag.flag)")
    }
    return resolvedFlag.flag.components(separatedBy: "/")[1]
}
