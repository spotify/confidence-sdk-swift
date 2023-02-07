import Foundation
import OpenFeature

/// The implementation of the konfidens feature provider.
///
///
///
public class KonfidensFeatureProvider: FeatureProvider {
    public var hooks: [AnyHook] = []
    public var metadata: Metadata = KonfidensMetadata()

    private var lock = UnfairLock()
    private var resolver: Resolver
    private var resolverWrapper: ResolverWrapper

    /// Should not be called externally, use `KonfidensFeatureProvider.Builder` instead.
    init(resolver: Resolver, overrides: [String: LocalOverride] = [:]) {
        self.resolver = resolver
        self.resolverWrapper = ResolverWrapper(resolver: resolver, overrides: overrides)
    }

    public func getBooleanEvaluation(key: String, defaultValue: Bool, ctx: EvaluationContext) throws
        -> ProviderEvaluation<
            Bool
        >
    {
        return try resolverWrapper.errorWrappedResolveFlag(
            flag: key,
            defaultValue: defaultValue,
            ctx: ctx,
            errorPrefix: "Error during boolean evaluation for key \(key)"
        ).providerEvaluation
    }

    public func getStringEvaluation(key: String, defaultValue: String, ctx: EvaluationContext) throws
        -> ProviderEvaluation<
            String
        >
    {
        return try resolverWrapper.errorWrappedResolveFlag(
            flag: key,
            defaultValue: defaultValue,
            ctx: ctx,
            errorPrefix: "Error during string evaluation for key \(key)"
        ).providerEvaluation
    }

    public func getIntegerEvaluation(key: String, defaultValue: Int64, ctx: EvaluationContext) throws
        -> ProviderEvaluation<
            Int64
        >
    {
        return try resolverWrapper.errorWrappedResolveFlag(
            flag: key,
            defaultValue: defaultValue,
            ctx: ctx,
            errorPrefix: "Error during integer evaluation for key \(key)"
        ).providerEvaluation
    }

    public func getDoubleEvaluation(key: String, defaultValue: Double, ctx: EvaluationContext) throws
        -> ProviderEvaluation<
            Double
        >
    {
        return try resolverWrapper.errorWrappedResolveFlag(
            flag: key,
            defaultValue: defaultValue,
            ctx: ctx,
            errorPrefix: "Error during double evaluation for key \(key)"
        ).providerEvaluation
    }

    public func getObjectEvaluation(key: String, defaultValue: Value, ctx: EvaluationContext) throws
        -> ProviderEvaluation<
            Value
        >
    {
        return try resolverWrapper.errorWrappedResolveFlag(
            flag: key,
            defaultValue: defaultValue,
            ctx: ctx,
            errorPrefix: "Error during object evaluation for key \(key)"
        ).providerEvaluation
    }

    /// Allows you to override directly on the provider. See `overrides` on ``Builder`` for more information.
    ///
    /// For example
    ///
    ///     (OpenFeatureAPI.shared.provider as? KonfidensFeatureProvider)?
    ///         .overrides(.field(path: "button.size", variant: "control", value: .integer(4)))
    public func overrides(_ overrides: LocalOverride...) {
        lock.locked {
            overrides.forEach { localOverride in
                resolverWrapper.overrides[localOverride.key()] = localOverride
            }
        }
    }
}

extension KonfidensFeatureProvider {
    public struct Builder {
        var options: RemoteKonfidensClient.KonfidensClientOptions
        var session: URLSession?
        var localOverrides: [String: LocalOverride] = [:]

        /// Initializes the builder with the given credentails.
        ///
        ///     OpenFeatureAPI.shared.provider =
        ///     KonfidensFeatureProvider.Builder(credentials: .clientSecret(secret: "mysecret"))
        ///         .build()
        public init(credentials: RemoteKonfidensClient.KonfidensClientCredentials) {
            self.options = RemoteKonfidensClient.KonfidensClientOptions(credentials: credentials)
        }

        init(
            options: RemoteKonfidensClient.KonfidensClientOptions,
            session: URLSession? = nil,
            localOverrides: [String: LocalOverride] = [:]
        ) {
            self.options = options
            self.session = session
            self.localOverrides = localOverrides
        }

        /// Allows the `KonfidensClient` to be configured with a custom URLSession, useful for
        /// setting up unit tests.
        ///
        /// - Parameters:
        ///      - session: URLSession to use for connections.
        public func with(session: URLSession) -> Builder {
            return Builder(
                options: options,
                session: session,
                localOverrides: localOverrides)
        }

        /// Locally overrides resolves for specific flags or even fields within a flag. Field-level overrides are
        /// prioritized over flag-level overrides ones.
        ///
        /// For example, the following will override the size field of a flag called button:
        ///
        ///     OpenFeatureAPI.shared.provider =
        ///         KonfidensFeatureProvider.Builder(credentials: .clientSecret(secret: "mysecret"))
        ///         .overrides(.field(path: "button.size", variant: "control", value: .integer(4)))
        ///         .build()
        ///
        /// You can alsow override the complete flag by:
        ///
        ///     OpenFeatureAPI.shared.provider =
        ///         KonfidensFeatureProvider.Builder(credentials: .clientSecret(secret: "mysecret"))
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
                localOverrides: self.localOverrides.merging(localOverrides) { _, new in new })
        }

        /// Creates the `KonfidensFeatureProvider` according to the settings specified in the builder.
        public func build() -> KonfidensFeatureProvider {
            let client = RemoteKonfidensClient(options: options, session: self.session, sendApplyEvent: true)
            return KonfidensFeatureProvider(resolver: client, overrides: self.localOverrides)
        }
    }
}
