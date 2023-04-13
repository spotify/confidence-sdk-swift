import Foundation
import OpenFeature

public class RemoteKonfidensClient: KonfidensClient {
    private let domain = "konfidens.services"
    private let resolveRoute = "/v1/flags"
    private let targetingKey = "targeting_key"

    private let baseUrl: String
    private var options: KonfidensClientOptions

    private var httpClient: HttpClient
    private var applyOnResolve: Bool

    init(options: KonfidensClientOptions, session: URLSession? = nil, applyOnResolve: Bool) {
        self.options = options
        self.baseUrl = "https://resolver.\(options.region.rawValue).\(domain)"
        if let session = session {
            self.httpClient = HttpClient(session: session)
        } else {
            self.httpClient = HttpClient()
        }
        self.applyOnResolve = applyOnResolve
    }
    public func resolve(flags: [String], ctx: EvaluationContext) throws -> ResolvesResult {
        let request = ResolveFlagsRequest(
            flags: flags.map { flag in
                "flags/\(flag)"
            },
            evaluationContext: try getEvaluationContextStruct(ctx: ctx),
            clientSecret: options.credentials.getSecret(),
            apply: applyOnResolve)
        guard let url = URL(string: "\(self.baseUrl)\(self.resolveRoute):resolve") else {
            throw KonfidensError.internalError(message: "Could not create service url")
        }

        do {
            let result = try self.httpClient.post(url: url, data: request, resultType: ResolveFlagsResponse.self)
            guard result.response.status == .ok else {
                throw mapHttpStatusToError(status: result.response.status, error: result.decodedError)
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

    public func apply(flag: String, resolveToken: String, applyTime: Date) throws {
        let appliedFlag = AppliedFlag(
            flag: "flags/\(flag)",
            applyTime: Date.backport.toISOString(date: applyTime))
        let request = ApplyFlagsRequest(
            flags: [appliedFlag],
            sendTime: Date.backport.nowISOString,
            clientSecret: options.credentials.getSecret(),
            resolveToken: resolveToken)
        guard let url = URL(string: "\(self.baseUrl)\(self.resolveRoute):apply") else {
            throw KonfidensError.internalError(message: "Could not create service url")
        }

        do {
            let result = try self.httpClient.post(url: url, data: request, resultType: ApplyFlagsResponse.self)
            guard result.response.status == .ok else {
                throw mapHttpStatusToError(status: result.response.status, error: result.decodedError, flag: flag)
            }
        } catch let error {
            throw handleError(error: error)
        }
    }

    private func convert(resolvedFlag: ResolvedFlag, ctx: EvaluationContext) throws -> ResolvedValue {
        guard let responseFlagSchema = resolvedFlag.flagSchema,
            let responseValue = resolvedFlag.value,
            !responseValue.fields.isEmpty
        else {
            return ResolvedValue(
                value: nil,
                flag: try displayName(resolvedFlag: resolvedFlag),
                applyStatus: applyOnResolve ? .applied : .notApplied)
        }

        let value = try TypeMapper.from(object: responseValue, schema: responseFlagSchema)
        let variant = resolvedFlag.variant.isEmpty ? nil : resolvedFlag.variant

        return ResolvedValue(
            variant: variant,
            value: value,
            flag: try displayName(resolvedFlag: resolvedFlag),
            applyStatus: applyOnResolve ? .applied : .notApplied)
    }

    private func getEvaluationContextStruct(ctx: EvaluationContext) throws -> Struct {
        var evaluationContext = TypeMapper.from(value: ctx)
        evaluationContext.fields[targetingKey] = .string(ctx.getTargetingKey())
        return evaluationContext
    }

    private func mapHttpStatusToError(status: HTTPStatusCode?, error: HttpError?, flag: String = "unknown") -> Error {
        let defaultError = OpenFeatureError.generalError(
            message: "General error: \(error?.message ?? "Unknown error")")

        switch status {
        case .notFound:
            return OpenFeatureError.flagNotFoundError(key: flag)
        case .badRequest:
            return KonfidensError.badRequest(message: error?.message ?? "")
        default:
            return defaultError
        }
    }

    private func handleError(error: Error) -> Error {
        if error is KonfidensError || error is OpenFeatureError {
            return error
        } else {
            return KonfidensError.grpcError(message: "\(error)")
        }
    }
}

extension RemoteKonfidensClient {
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
        case unknown
    }

    struct ApplyFlagsRequest: Codable {
        var flags: [AppliedFlag]
        var sendTime: String
        var clientSecret: String
        var resolveToken: String
    }

    struct ApplyFlagsResponse: Codable {
    }

    struct AppliedFlag: Codable {
        var flag: String
        var applyTime: String
    }
}

extension RemoteKonfidensClient {
    public struct KonfidensClientOptions {
        public var credentials: KonfidensClientCredentials
        public var timeout: TimeInterval
        public var region: KonfidensRegion

        public init(
            credentials: KonfidensClientCredentials, timeout: TimeInterval? = nil, region: KonfidensRegion? = nil
        ) {
            self.credentials = credentials
            self.timeout = timeout ?? 10.0
            self.region = region ?? .europe
        }
    }

    public enum KonfidensClientCredentials {
        case clientSecret(secret: String)

        public func getSecret() -> String {
            switch self {
            case .clientSecret(let secret):
                return secret
            }
        }
    }

    public enum KonfidensRegion: String {
        case europe = "eu"
        case usa = "us"
    }

    private func displayName(resolvedFlag: ResolvedFlag) throws -> String {
        let flagNameComponents = resolvedFlag.flag.components(separatedBy: "/")
        if flagNameComponents.count <= 1 || flagNameComponents[0] != "flags" {
            throw KonfidensError.internalError(message: "Unxpected flag name: \(resolvedFlag.flag)")
        }
        return resolvedFlag.flag.components(separatedBy: "/")[1]
    }
}
