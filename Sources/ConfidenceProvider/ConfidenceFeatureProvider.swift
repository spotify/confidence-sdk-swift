import Foundation
import Combine
import Confidence
import OpenFeature
import os

struct Metadata: ProviderMetadata {
    var name: String?
}

/// The implementation of the Confidence Feature Provider. This implementation allows to pre-cache evaluations.
public class ConfidenceFeatureProvider: FeatureProvider {
    public var metadata: ProviderMetadata
    public var hooks: [any Hook] = []
    private let lock = UnfairLock()
    private let initializationStrategy: InitializationStrategy
    private let eventHandler = EventHandler(ProviderEvent.notReady)
    private let confidence: Confidence
    private var cancellables = Set<AnyCancellable>()
    private var currentResolveTask: Task<Void, Never>?
    private let confidenceFeatureProviderQueue = DispatchQueue(label: "com.provider.queue")

    /// Initialize the Provider via a `Confidence` object.
    public convenience init(confidence: Confidence, initializationStrategy: InitializationStrategy = .fetchAndActivate) {
        self.init(confidence: confidence, session: nil)
    }

    internal init(
        confidence: Confidence,
        initializationStrategy: InitializationStrategy = .fetchAndActivate,
        session: URLSession?
    ) {
        let metadata = ConfidenceMetadata(version: "0.1.4") // x-release-please-version
        self.metadata = Metadata(name: metadata.name)
        self.initializationStrategy = initializationStrategy
        self.confidence = confidence
    }

    public func initialize(initialContext: OpenFeature.EvaluationContext?) {
        guard let initialContext = initialContext else {
            return
        }

        self.updateConfidenceContext(context: initialContext)
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
                    try await confidence.fetchAndActivate()
                    eventHandler.send(.ready)
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
