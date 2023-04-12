import Foundation
import OpenFeature
import os

/// The implementation of the konfidens feature provider. This implementation allows to pre-cache evaluations.
///
///
///
public class KonfidensFeatureProvider: FeatureProvider {
    public var hooks: [AnyHook] = []
    public var metadata: Metadata = KonfidensMetadata()
    private var applyQueue: DispatchQueueType
    private var lock = UnfairLock()
    private var resolver: Resolver
    private var client: KonfidensClient
    private var cache: ProviderCache
    private var resolverWrapper: ResolverWrapper
    private var currentCtx: EvaluationContext?

    /// Should not be called externally, use `KonfidensFeatureProvider.Builder` instead.
    init(
        resolver: Resolver,
        client: RemoteKonfidensClient,
        cache: ProviderCache,
        overrides: [String: LocalOverride] = [:],
        applyQueue: DispatchQueueType = DispatchQueue(label: "com.konfidens.apply", attributes: .concurrent)
    ) {
        self.applyQueue = applyQueue
        self.resolver = resolver
        self.client = client
        self.cache = cache
        self.resolverWrapper = ResolverWrapper(resolver: resolver, overrides: overrides)
    }

    public func initialize(initialContext: OpenFeature.EvaluationContext?) {
        guard let initialContext = initialContext else {
            return
        }
        processNewContext(context: initialContext)
    }

    public func onContextSet(oldContext: OpenFeature.EvaluationContext?, newContext: OpenFeature.EvaluationContext) {
        guard self.currentCtx?.hash() != newContext.hash() else {
            return
        }
        processNewContext(context: newContext)
    }

    public func getBooleanEvaluation(key: String, defaultValue: Bool) throws
        -> OpenFeature.ProviderEvaluation<Bool>
    {
        guard let invocationCtx = self.currentCtx else {
            throw OpenFeatureError.targetingKeyMissingError
        }
        let (evaluationResult, resolverResult) = try resolverWrapper.errorWrappedResolveFlag(
            flag: key,
            defaultValue: defaultValue,
            ctx: invocationCtx,
            errorPrefix: "Error during boolean evaluation for key \(key)")
        processResultForApply(
            evaluationResult: evaluationResult,
            resolverResult: resolverResult,
            ctx: invocationCtx,
            applyTime: Date.backport.now)
        return evaluationResult
    }

    public func getStringEvaluation(key: String, defaultValue: String) throws
        -> OpenFeature.ProviderEvaluation<String>
    {
        guard let invocationCtx = self.currentCtx else {
            throw OpenFeatureError.targetingKeyMissingError
        }
        let (evaluationResult, resolverResult) = try resolverWrapper.errorWrappedResolveFlag(
            flag: key,
            defaultValue: defaultValue,
            ctx: invocationCtx,
            errorPrefix: "Error during string evaluation for key \(key)")
        processResultForApply(
            evaluationResult: evaluationResult,
            resolverResult: resolverResult,
            ctx: invocationCtx,
            applyTime: Date.backport.now)
        return evaluationResult
    }

    public func getIntegerEvaluation(key: String, defaultValue: Int64) throws
        -> OpenFeature.ProviderEvaluation<Int64>
    {
        guard let invocationCtx = self.currentCtx else {
            throw OpenFeatureError.targetingKeyMissingError
        }
        let (evaluationResult, resolverResult) = try resolverWrapper.errorWrappedResolveFlag(
            flag: key,
            defaultValue: defaultValue,
            ctx: invocationCtx,
            errorPrefix: "Error during integer evaluation for key \(key)")
        processResultForApply(
            evaluationResult: evaluationResult,
            resolverResult: resolverResult,
            ctx: invocationCtx,
            applyTime: Date.backport.now)
        return evaluationResult
    }

    public func getDoubleEvaluation(key: String, defaultValue: Double) throws
        -> OpenFeature.ProviderEvaluation<Double>
    {
        guard let invocationCtx = self.currentCtx else {
            throw OpenFeatureError.targetingKeyMissingError
        }
        let (evaluationResult, resolverResult) = try resolverWrapper.errorWrappedResolveFlag(
            flag: key,
            defaultValue: defaultValue,
            ctx: invocationCtx,
            errorPrefix: "Error during double evaluation for key \(key)")
        processResultForApply(
            evaluationResult: evaluationResult,
            resolverResult: resolverResult,
            ctx: invocationCtx,
            applyTime: Date.backport.now)
        return evaluationResult
    }

    public func getObjectEvaluation(key: String, defaultValue: OpenFeature.Value)
        throws -> OpenFeature.ProviderEvaluation<OpenFeature.Value>
    {
        guard let invocationCtx = self.currentCtx else {
            throw OpenFeatureError.targetingKeyMissingError
        }
        let (evaluationResult, resolverResult) = try resolverWrapper.errorWrappedResolveFlag(
            flag: key,
            defaultValue: defaultValue,
            ctx: invocationCtx,
            errorPrefix: "Error during object evaluation for key \(key)")
        processResultForApply(
            evaluationResult: evaluationResult,
            resolverResult: resolverResult,
            ctx: invocationCtx,
            applyTime: Date.backport.now)
        return evaluationResult
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

    private func processNewContext(context: OpenFeature.EvaluationContext) {
        self.currentCtx = context
        // Racy: local ctx and ctx in cache might differ until the latter is updated, resulting in STALE evaluations
        do {
            let resolveResult = try client.resolve(ctx: context)
            guard let resolveToken = resolveResult.resolveToken else {
                throw KonfidensError.noResolveTokenFromServer
            }
            try cache.clearAndSetValues(
                values: resolveResult.resolvedValues, ctx: context, resolveToken: resolveToken)
        } catch let error {
            Logger(subsystem: "com.konfidens.provider", category: "initialize").error(
                "Error while executing \"initialize\": \(error)")
        }
    }

    private func processResultForApply<T>(
        evaluationResult: ProviderEvaluation<T>,
        resolverResult: ResolveResult?,
        ctx: OpenFeature.EvaluationContext,
        applyTime: Date
    ) {
        guard evaluationResult.errorCode == nil, let resolverResult = resolverResult,
            let resolveToken = resolverResult.resolveToken
        else {
            return
        }

        let flag = resolverResult.resolvedValue.flag
        do {
            if try cache.updateApplyStatus(
                flag: flag, ctx: ctx, resolveToken: resolveToken, applyStatus: .applying)
            {
                executeApply(client: client, flag: flag, resolveToken: resolveToken) { success in
                    do {
                        if success {
                            _ = try self.cache.updateApplyStatus(
                                flag: flag, ctx: ctx, resolveToken: resolveToken, applyStatus: .applied)
                        } else {
                            _ = try self.cache.updateApplyStatus(
                                flag: flag, ctx: ctx, resolveToken: resolveToken, applyStatus: .applyFailed)
                        }
                    } catch let error {
                        self.logApplyError(error: error)
                    }
                }
            }
        } catch let error {
            logApplyError(error: error)
        }
    }

    private func executeApply(
        client: KonfidensClient, flag: String, resolveToken: String, completion: @escaping (Bool) -> Void
    ) {
        applyQueue.async {
            do {
                try client.apply(flag: flag, resolveToken: resolveToken, applyTime: Date.backport.now)
                completion(true)
            } catch let error {
                self.logApplyError(error: error)
                completion(false)
            }
        }
    }

    private func logApplyError(error: Error) {
        switch error {
        case KonfidensError.applyStatusTransitionError, KonfidensError.cachedValueExpired,
            KonfidensError.flagNotFoundInCache:
            Logger(subsystem: "com.konfidens.provider", category: "apply").debug(
                "Cache data for flag was updated while executing \"apply\", aborting")
        default:
            Logger(subsystem: "com.konfidens.provider", category: "apply").error(
                "Error while executing \"apply\": \(error)")
        }
    }
}

extension KonfidensFeatureProvider {
    public struct Builder {
        var options: RemoteKonfidensClient.KonfidensClientOptions
        var session: URLSession?
        var localOverrides: [String: LocalOverride] = [:]
        var applyQueue: DispatchQueueType = DispatchQueue(label: "com.konfidens.apply", attributes: .concurrent)
        var cache: ProviderCache = PersistentProviderCache.fromDefaultStorage()

        /// Initializes the builder with the given credentails.
        ///
        ///     OpenFeatureAPI.shared.setProvider(provider:
        ///     KonfidensFeatureProvider.Builder(credentials: .clientSecret(secret: "mysecret"))
        ///         .build()
        public init(credentials: RemoteKonfidensClient.KonfidensClientCredentials) {
            self.options = RemoteKonfidensClient.KonfidensClientOptions(credentials: credentials)
        }

        init(
            options: RemoteKonfidensClient.KonfidensClientOptions,
            session: URLSession? = nil,
            localOverrides: [String: LocalOverride] = [:],
            applyQueue: DispatchQueueType = DispatchQueue(label: "com.konfidens.apply", attributes: .concurrent),
            cache: ProviderCache = PersistentProviderCache.fromDefaultStorage()
        ) {
            self.options = options
            self.session = session
            self.localOverrides = localOverrides
            self.applyQueue = applyQueue
            self.cache = cache
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
                localOverrides: localOverrides,
                applyQueue: applyQueue,
                cache: cache)
        }

        /// Inject custom queue for Apply request operations, useful for testing
        ///
        /// - Parameters:
        ///      - applyQueue: queue to use for sending Apply requests.
        public func with(applyQueue: DispatchQueueType) -> Builder {
            return Builder(
                options: options,
                session: session,
                localOverrides: localOverrides,
                applyQueue: applyQueue,
                cache: cache)
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
                applyQueue: applyQueue,
                cache: cache)
        }

        /// Locally overrides resolves for specific flags or even fields within a flag. Field-level overrides are
        /// prioritized over flag-level overrides ones.
        ///
        /// For example, the following will override the size field of a flag called button:
        ///
        ///     OpenFeatureAPI.shared.setProvider(provider:
        ///         KonfidensFeatureProvider.Builder(credentials: .clientSecret(secret: "mysecret"))
        ///         .overrides(.field(path: "button.size", variant: "control", value: .integer(4)))
        ///         .build()
        ///
        /// You can alsow override the complete flag by:
        ///
        ///     OpenFeatureAPI.shared.setProvider(provider:
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
                localOverrides: self.localOverrides.merging(localOverrides) { _, new in new },
                applyQueue: applyQueue,
                cache: cache)
        }

        /// Creates the `KonfidensFeatureProvider` according to the settings specified in the builder.
        public func build() -> KonfidensFeatureProvider {
            let client = RemoteKonfidensClient(options: options, session: self.session, applyOnResolve: false)
            let resolver = LocalStorageResolver(cache: cache)
            return KonfidensFeatureProvider(
                resolver: resolver, client: client, cache: cache, overrides: localOverrides, applyQueue: applyQueue)
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
