import Foundation
import Combine
import Confidence
import OpenFeature
import os

struct Metadata: ProviderMetadata {
    var name: String? = ConfidenceFeatureProvider.providerId
}

/// The implementation of the Confidence Feature Provider. This implementation allows to pre-cache evaluations.
public class ConfidenceFeatureProvider: FeatureProvider {
    public static let providerId: String = "SDK_ID_SWIFT_PROVIDER"

    public var metadata: ProviderMetadata = Metadata()
    public var hooks: [any Hook] = []
    private let lock = UnfairLock()
    private let initializationStrategy: InitializationStrategy
    private let eventHandler = EventHandler(ProviderEvent.notReady)
    private let confidence: Confidence
    private var cancellables = Set<AnyCancellable>()
    private var currentResolveTask: Task<Void, Never>?
    private let confidenceFeatureProviderQueue = DispatchQueue(label: "com.provider.queue")

    /**
    Creates the `Confidence` object to be used as init parameter for this Provider.
    */
    public static func createConfidence(clientSecret: String) -> ConfidenceForOpenFeature {
        return ConfidenceForOpenFeature.init(confidence: Confidence.Builder.init(clientSecret: clientSecret)
            .withRegion(region: .global)
            .withMetadata(metadata: ConfidenceMetadata.init(
                name: providerId,
                version: "0.2.2") // x-release-please-version
            )
            .build())
    }

    /**
    Proxy holder to ensure correct Confidence configuration passed into the Provider's init.
    Do not instantiate directly.
    */
    public class ConfidenceForOpenFeature {
        internal init(confidence: Confidence) {
            self.confidence = confidence
        }
        let confidence: Confidence
    }

    /**
    Initialize the Provider via a `Confidence` object.
    The `Confidence` object must be creted via the `createConfidence` function available from this same class,
    rather then be instantiated directly via `Confidence.init(...)` as you would if not using the OpenFeature integration.
    */
    public convenience init(
        confidenceForOF: ConfidenceForOpenFeature,
        initializationStrategy: InitializationStrategy = .fetchAndActivate
    ) {
        self.init(confidence: confidenceForOF.confidence, session: nil)
    }

    // Allows to pass a confidence object with injected configurations for testing
    internal convenience init(
        confidence: Confidence,
        initializationStrategy: InitializationStrategy = .fetchAndActivate
    ) {
        self.init(confidence: confidence, session: nil)
    }

    internal init(
        confidence: Confidence,
        initializationStrategy: InitializationStrategy = .fetchAndActivate,
        session: URLSession?
    ) {
        self.initializationStrategy = initializationStrategy
        self.confidence = confidence
    }

    public func initialize(initialContext: OpenFeature.EvaluationContext?) {
        self.updateConfidenceContext(context: initialContext ?? MutableContext(attributes: [:]))
        if self.initializationStrategy == .activateAndFetchAsync {
            eventHandler.send(.ready)
        }

        do {
            if initializationStrategy == .activateAndFetchAsync {
                try confidence.activate()
                eventHandler.send(.ready)
                confidence.asyncFetch()
            } else {
                Task {
                    do {
                        try await confidence.fetchAndActivate()
                        eventHandler.send(.ready)
                    } catch {
                        eventHandler.send(.error)
                    }
                }
            }
        } catch {
            eventHandler.send(.error)
        }
    }

    func shutdown() {
        for cancellable in cancellables {
            cancellable.cancel()
        }
        cancellables.removeAll()
        currentResolveTask?.cancel()
    }

    public func onContextSet(
        oldContext: OpenFeature.EvaluationContext?,
        newContext: OpenFeature.EvaluationContext
    ) {
        var removedKeys: [String] = []
        if let oldContext = oldContext {
            removedKeys = Array(oldContext.asMap().filter { key, _ in !newContext.asMap().keys.contains(key) }.keys)
        }

        self.updateConfidenceContext(context: newContext, removedKeys: removedKeys)
    }

    private func updateConfidenceContext(context: EvaluationContext, removedKeys: [String] = []) {
        confidence.putContext(context: ConfidenceTypeMapper.from(ctx: context), removeKeys: removedKeys)
    }

    public func getBooleanEvaluation(key: String, defaultValue: Bool, context: EvaluationContext?) throws
    -> OpenFeature.ProviderEvaluation<Bool>
    {
        try confidence.getEvaluation(key: key, defaultValue: defaultValue).toProviderEvaluation()
    }

    public func getStringEvaluation(key: String, defaultValue: String, context: EvaluationContext?) throws
    -> OpenFeature.ProviderEvaluation<String>
    {
        try confidence.getEvaluation(key: key, defaultValue: defaultValue).toProviderEvaluation()
    }

    public func getIntegerEvaluation(key: String, defaultValue: Int64, context: EvaluationContext?) throws
    -> OpenFeature.ProviderEvaluation<Int64>
    {
        try confidence.getEvaluation(key: key, defaultValue: defaultValue).toProviderEvaluation()
    }

    public func getDoubleEvaluation(key: String, defaultValue: Double, context: EvaluationContext?) throws
    -> OpenFeature.ProviderEvaluation<Double>
    {
        try confidence.getEvaluation(key: key, defaultValue: defaultValue).toProviderEvaluation()
    }

    public func getObjectEvaluation(key: String, defaultValue: OpenFeature.Value, context: EvaluationContext?)
    throws -> OpenFeature.ProviderEvaluation<OpenFeature.Value>
    {
        try confidence.getEvaluation(key: key, defaultValue: defaultValue).toProviderEvaluation()
    }

    public func observe() -> AnyPublisher<OpenFeature.ProviderEvent, Never> {
        return eventHandler.observe()
    }

    private func withLock(callback: @escaping (ConfidenceFeatureProvider) -> Void) {
        confidenceFeatureProviderQueue.sync {  [weak self] in
            guard let self = self else {
                return
            }
            callback(self)
        }
    }
}

extension Evaluation {
    func toProviderEvaluation() -> ProviderEvaluation<T> {
        ProviderEvaluation(
            value: self.value,
            variant: self.variant,
            reason: self.reason.rawValue,
            errorCode: nil,
            errorMessage: nil
        )
    }
}
