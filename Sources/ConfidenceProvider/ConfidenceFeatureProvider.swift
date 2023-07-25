import Foundation
import OpenFeature
import os

/// The implementation of the Confidence Feature Provider. This implementation allows to pre-cache evaluations.
///
///
///
// swiftlint:disable type_body_length
// swiftlint:disable file_length
public class ConfidenceFeatureProvider: FeatureProvider {
    public var hooks: [any Hook] = []
    public let metadata: Metadata = ConfidenceMetadata()
    private let lock = UnfairLock()
    private let resolver: Resolver
    private let client: ConfidenceClient
    private let cache: ProviderCache
    private var overrides: [String: LocalOverride]
    private let flagApplier: FlagApplier

    /// Should not be called externally, use `ConfidenceFeatureProvider.Builder` instead.
    init(
        resolver: Resolver,
        client: RemoteConfidenceClient,
        cache: ProviderCache,
        overrides: [String: LocalOverride] = [:],
        flagApplier: FlagApplier,
        applyStorage: Storage
    ) {
        self.resolver = resolver
        self.client = client
        self.cache = cache
        self.overrides = overrides
        self.flagApplier = flagApplier
    }

    public func initialize(initialContext: OpenFeature.EvaluationContext?) async {
        guard let initialContext = initialContext else {
            return
        }

        await processNewContext(context: initialContext)
    }

    public func onContextSet(
        oldContext: OpenFeature.EvaluationContext?,
        newContext: OpenFeature.EvaluationContext
    ) async {
        guard oldContext?.hash() != newContext.hash() else {
            return
        }

        await processNewContext(context: newContext)
    }

    public func getBooleanEvaluation(key: String, defaultValue: Bool, context: EvaluationContext?) throws
        -> OpenFeature.ProviderEvaluation<Bool>
    {
        return try errorWrappedResolveFlag(
            flag: key,
            defaultValue: defaultValue,
            ctx: context,
            errorPrefix: "Error during boolean evaluation for key \(key)")
    }

    public func getStringEvaluation(key: String, defaultValue: String, context: EvaluationContext?) throws
        -> OpenFeature.ProviderEvaluation<String>
    {
        return try errorWrappedResolveFlag(
            flag: key,
            defaultValue: defaultValue,
            ctx: context,
            errorPrefix: "Error during string evaluation for key \(key)")
    }

    public func getIntegerEvaluation(key: String, defaultValue: Int64, context: EvaluationContext?) throws
        -> OpenFeature.ProviderEvaluation<Int64>
    {
        return try errorWrappedResolveFlag(
            flag: key,
            defaultValue: defaultValue,
            ctx: context,
            errorPrefix: "Error during integer evaluation for key \(key)")
    }

    public func getDoubleEvaluation(key: String, defaultValue: Double, context: EvaluationContext?) throws
        -> OpenFeature.ProviderEvaluation<Double>
    {
        return try errorWrappedResolveFlag(
            flag: key,
            defaultValue: defaultValue,
            ctx: context,
            errorPrefix: "Error during double evaluation for key \(key)")
    }

    public func getObjectEvaluation(key: String, defaultValue: OpenFeature.Value, context: EvaluationContext?)
        throws -> OpenFeature.ProviderEvaluation<OpenFeature.Value>
    {
        return try errorWrappedResolveFlag(
            flag: key,
            defaultValue: defaultValue,
            ctx: context,
            errorPrefix: "Error during object evaluation for key \(key)")
    }

    /// Allows you to override directly on the provider. See `overrides` on ``Builder`` for more information.
    ///
    /// For example
    ///
    ///     (OpenFeatureAPI.shared.provider as? ConfidenceFeatureProvider)?
    ///         .overrides(.field(path: "button.size", variant: "control", value: .integer(4)))
    public func overrides(_ overrides: LocalOverride...) {
        lock.locked {
            overrides.forEach { localOverride in
                self.overrides[localOverride.key()] = localOverride
            }
        }
    }

    private func processNewContext(context: OpenFeature.EvaluationContext) async {
        // Racy: eval ctx and ctx in cache might differ until the latter is updated, resulting in STALE evaluations
        do {
            let resolveResult = try await client.resolve(ctx: context)
            guard let resolveToken = resolveResult.resolveToken else {
                throw ConfidenceError.noResolveTokenFromServer
            }
            try cache.clearAndSetValues(
                values: resolveResult.resolvedValues, ctx: context, resolveToken: resolveToken)
        } catch let error {
            Logger(subsystem: "com.confidence.provider", category: "initialize").error(
                "Error while executing \"initialize\": \(error)")
        }
    }

    public func errorWrappedResolveFlag<T>(flag: String, defaultValue: T, ctx: EvaluationContext?, errorPrefix: String)
        throws -> ProviderEvaluation<T>
    {
        do {
            let path = try FlagPath.getPath(for: flag)
            return try resolveFlag(path: path, defaultValue: defaultValue, ctx: ctx)
        } catch let error {
            if error is OpenFeatureError {
                throw error
            } else {
                throw OpenFeatureError.generalError(message: "\(errorPrefix): \(error)")
            }
        }
    }

    private func resolveFlag<T>(path: FlagPath, defaultValue: T, ctx: EvaluationContext?) throws -> ProviderEvaluation<
        T
    > {
        if let overrideValue: (value: T, variant: String?) = getOverride(path: path) {
            return ProviderEvaluation(
                value: overrideValue.value,
                variant: overrideValue.variant,
                reason: Reason.staticReason.rawValue)
        }

        guard let ctx = ctx else {
            throw OpenFeatureError.invalidContextError
        }

        do {
            let resolverResult = try resolver.resolve(flag: path.flag, ctx: ctx)

            guard let value = resolverResult.resolvedValue.value else {
                return resolveFlagNoValue(
                    defaultValue: defaultValue,
                    resolverResult: resolverResult,
                    ctx: ctx
                )
            }

            let pathValue: Value = try getValue(path: path.path, value: value)
            guard let typedValue: T = pathValue == .null ? defaultValue : pathValue.getTyped() else {
                throw OpenFeatureError.parseError(message: "Unable to parse flag value: \(pathValue)")
            }

            let evaluationResult = ProviderEvaluation(
                value: typedValue,
                variant: resolverResult.resolvedValue.variant,
                reason: Reason.targetingMatch.rawValue
            )

            processResultForApply(
                resolverResult: resolverResult,
                ctx: ctx,
                applyTime: Date.backport.now
            )
            return evaluationResult
        } catch ConfidenceError.cachedValueExpired {
            return ProviderEvaluation(value: defaultValue, variant: nil, reason: Reason.stale.rawValue)
        } catch {
            throw error
        }
    }

    private func resolveFlagNoValue<T>(defaultValue: T, resolverResult: ResolveResult, ctx: EvaluationContext)
        -> ProviderEvaluation<T>
    {
        switch resolverResult.resolvedValue.resolveReason {
        case .noMatch:
            processResultForApply(
                resolverResult: resolverResult,
                ctx: ctx,
                applyTime: Date.backport.now)
            return ProviderEvaluation(
                value: defaultValue,
                variant: nil,
                reason: Reason.defaultReason.rawValue)
        case .match:
            return ProviderEvaluation(
                value: defaultValue,
                variant: nil,
                reason: Reason.error.rawValue,
                errorCode: ErrorCode.general,
                errorMessage: "Rule matched but no value was returned")
        case .targetingKeyError:
            return ProviderEvaluation(
                value: defaultValue,
                variant: nil,
                reason: Reason.error.rawValue,
                errorCode: ErrorCode.invalidContext,
                errorMessage: "Invalid targeting key")
        case .disabled:
            return ProviderEvaluation(
                value: defaultValue,
                variant: nil,
                reason: Reason.disabled.rawValue)
        case .generalError:
            return ProviderEvaluation(
                value: defaultValue,
                variant: nil,
                reason: Reason.error.rawValue,
                errorCode: ErrorCode.general,
                errorMessage: "General error in the Confidence backend")
        }
    }

    private func getValue(path: [String], value: Value) throws -> Value {
        if path.isEmpty {
            guard case .structure = value else {
                throw OpenFeatureError.parseError(
                    message: "Flag path must contain path to the field for non-object values")
            }
        }

        var pathValue = value
        if !path.isEmpty {
            pathValue = try getValueForPath(path: path, value: value)
        }

        return pathValue
    }

    private func getValueForPath(path: [String], value: Value) throws -> Value {
        var curValue = value
        for field in path {
            guard case .structure(let values) = curValue, let newValue = values[field] else {
                throw OpenFeatureError.generalError(message: "Unable to find key '\(field)'")
            }

            curValue = newValue
        }

        return curValue
    }

    private func getOverride<T>(path: FlagPath) -> (value: T, variant: String?)? {
        let fieldPath = "\(path.flag).\(path.path.joined(separator: "."))"

        guard let overrideValue = self.overrides[fieldPath] ?? self.overrides[path.flag] else {
            return nil
        }

        switch overrideValue {
        case let .flag(_, variant, value):
            guard let pathValue = try? getValue(path: path.path, value: .structure(value)) else {
                return nil
            }
            guard let typedValue: T = pathValue.getTyped() else {
                return nil
            }

            return (typedValue, variant)

        case let .field(_, variant, value):
            guard let typedValue: T = value.getTyped() else {
                return nil
            }

            return (typedValue, variant)
        }
    }

    private func processResultForApply(
        resolverResult: ResolveResult?,
        ctx: OpenFeature.EvaluationContext?,
        applyTime: Date
    ) {
        guard let resolverResult = resolverResult, let resolveToken = resolverResult.resolveToken else {
            return
        }

        let flag = resolverResult.resolvedValue.flag
        Task {
            await flagApplier.apply(flagName: flag, resolveToken: resolveToken)
        }
    }

    private func logApplyError(error: Error) {
        switch error {
        case ConfidenceError.applyStatusTransitionError, ConfidenceError.cachedValueExpired,
            ConfidenceError.flagNotFoundInCache:
            Logger(subsystem: "com.confidence.provider", category: "apply").debug(
                "Cache data for flag was updated while executing \"apply\", aborting")
        default:
            Logger(subsystem: "com.confidence.provider", category: "apply").error(
                "Error while executing \"apply\": \(error)")
        }
    }
}

extension ConfidenceFeatureProvider {
    public struct Builder {
        var options: ConfidenceClientOptions
        var session: URLSession?
        var localOverrides: [String: LocalOverride] = [:]
        var cache: ProviderCache = PersistentProviderCache.from(
            storage: DefaultStorage(filePath: "resolver.flags.cache"))
        var flagApplier: (any FlagApplier)?
        var applyStorage: Storage = DefaultStorage(filePath: "resolver.apply.cache")

        /// Initializes the builder with the given credentails.
        ///
        ///     OpenFeatureAPI.shared.setProvider(provider:
        ///     ConfidenceFeatureProvider.Builder(credentials: .clientSecret(secret: "mysecret"))
        ///         .build()
        public init(credentials: ConfidenceClientCredentials) {
            self.options = ConfidenceClientOptions(credentials: credentials)
        }

        init(
            options: ConfidenceClientOptions,
            session: URLSession? = nil,
            localOverrides: [String: LocalOverride] = [:],
            flagApplier: FlagApplier?,
            cache: ProviderCache,
            applyStorage: Storage
        ) {
            self.options = options
            self.session = session
            self.localOverrides = localOverrides
            self.flagApplier = flagApplier
            self.cache = cache
            self.applyStorage = applyStorage
        }

        /// Allows the `ConfidenceClient` to be configured with a custom URLSession, useful for
        /// setting up unit tests.
        ///
        /// - Parameters:
        ///      - session: URLSession to use for connections.
        public func with(session: URLSession) -> Builder {
            return Builder(
                options: options,
                session: session,
                localOverrides: localOverrides,
                flagApplier: flagApplier,
                cache: cache,
                applyStorage: applyStorage
            )
        }

        /// Inject custom queue for Apply request operations, useful for testing
        ///
        /// - Parameters:
        ///      - applyQueue: queue to use for sending Apply requests.
        public func with(flagApplier: FlagApplier) -> Builder {
            return Builder(
                options: options,
                session: session,
                localOverrides: localOverrides,
                flagApplier: flagApplier,
                cache: cache,
                applyStorage: applyStorage
            )
        }

        /// Inject custom cache, useful for testing
        ///
        /// - Parameters:
        ///      - cache: cache for the provider to use.
        public func with(cache: ProviderCache) -> Builder {
            return Builder(
                options: options,
                session: session,
                localOverrides: localOverrides,
                flagApplier: flagApplier,
                cache: cache,
                applyStorage: applyStorage
            )
        }

        /// Inject custom storage for apply events, useful for testing
        ///
        /// - Parameters:
        ///      - storage: apply storage for the provider to use.
        public func with(applyStorage: Storage) -> Builder {
            return Builder(
                options: options,
                session: session,
                localOverrides: localOverrides,
                flagApplier: flagApplier,
                cache: cache,
                applyStorage: applyStorage
            )
        }

        /// Locally overrides resolves for specific flags or even fields within a flag. Field-level overrides are
        /// prioritized over flag-level overrides ones.
        ///
        /// For example, the following will override the size field of a flag called button:
        ///
        ///     OpenFeatureAPI.shared.setProvider(provider:
        ///         ConfidenceFeatureProvider.Builder(credentials: .clientSecret(secret: "mysecret"))
        ///         .overrides(.field(path: "button.size", variant: "control", value: .integer(4)))
        ///         .build()
        ///
        /// You can alsow override the complete flag by:
        ///
        ///     OpenFeatureAPI.shared.setProvider(provider:
        ///         ConfidenceFeatureProvider.Builder(credentials: .clientSecret(secret: "mysecret"))
        ///         .overrides(.flag(name: "button", variant: "control", value: ["size": .integer(4)]))
        ///         .build()
        ///
        /// - Parameters:
        ///      - overrides: the list of local overrides for the provider.
        public func overrides(_ overrides: LocalOverride...) -> Builder {
            let localOverrides = Dictionary(uniqueKeysWithValues: overrides.map { ($0.key(), $0) })

            return Builder(
                options: options,
                session: session,
                localOverrides: self.localOverrides.merging(localOverrides) { _, new in new },
                flagApplier: flagApplier,
                cache: cache,
                applyStorage: applyStorage
            )
        }

        /// Creates the `ConfidenceFeatureProvider` according to the settings specified in the builder.
        public func build() -> ConfidenceFeatureProvider {
            let flagApplier =
                flagApplier
                ?? FlagApplierWithRetries(
                    httpClient: NetworkClient(region: options.region),
                    storage: DefaultStorage(filePath: "applier.flags.cache"),
                    options: options
                )

            let client = RemoteConfidenceClient(
                options: options,
                session: self.session,
                applyOnResolve: false,
                flagApplier: flagApplier
            )
            let resolver = LocalStorageResolver(cache: cache)
            return ConfidenceFeatureProvider(
                resolver: resolver,
                client: client,
                cache: cache,
                overrides: localOverrides,
                flagApplier: flagApplier,
                applyStorage: applyStorage
            )
        }
    }
}

/// Used for testing
public protocol DispatchQueueType {
    func async(execute work: @escaping @convention(block) () -> Void)
}

extension DispatchQueue: DispatchQueueType {
    public func async(execute work: @escaping @convention(block) () -> Void) {
        async(group: nil, qos: .unspecified, flags: [], execute: work)
    }
}
