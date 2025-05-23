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
    public static let providerId: String = "SDK_ID_SWIFT_PROVIDER"
    public var metadata: ProviderMetadata
    public var hooks: [any Hook] = []
    private let lock = UnfairLock()
    private let initializationStrategy: InitializationStrategy
    private let eventHandler = EventHandler()
    private let confidence: Confidence
    private let confidenceFeatureProviderQueue = DispatchQueue(label: "com.provider.queue")
    private var cancellables = Set<AnyCancellable>()
    private var currentResolveTask: Task<Void, Never>?

    /**
    Initialize the Provider via a `Confidence` object.
    The `initializationStrategy` defines when the Provider is ready to read flags, before or after a refresh of the flag evaluation fata.
    */
    public convenience init(confidence: Confidence, initializationStrategy: InitializationStrategy = .fetchAndActivate) {
        self.init(confidence: confidence, initializationStrategy: initializationStrategy, session: nil)
    }

    internal init(
        confidence: Confidence,
        initializationStrategy: InitializationStrategy,
        session: URLSession?
    ) {
        self.metadata = Metadata(name: ConfidenceFeatureProvider.providerId)
        self.initializationStrategy = initializationStrategy
        self.confidence = confidence
    }

    public func initialize(initialContext: OpenFeature.EvaluationContext?) async throws {
        let context = ConfidenceTypeMapper.from(ctx: initialContext ?? MutableContext(attributes: [:]))
        confidence.putContextLocal(context: context)
        if initializationStrategy == .activateAndFetchAsync {
            try confidence.activate()
            Task {
                await confidence.asyncFetch()
            }
        } else {
            try await confidence.fetchAndActivate()
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
    ) async {
        let removedKeys: [String] = oldContext.map {
            Array($0.asMap().filter { key, _ in !newContext.asMap().keys.contains(key) }.keys)
        } ?? []
        await confidence.putContextAndWait(
            context: ConfidenceTypeMapper.from(ctx: newContext),
            removedKeys: removedKeys)
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

    public func observe() -> AnyPublisher<OpenFeature.ProviderEvent?, Never> {
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
    func toProviderEvaluation() throws -> ProviderEvaluation<T> {
        if let errorCode = self.errorCode {
            switch errorCode {
            case .providerNotReady:
                throw OpenFeatureError.providerNotReadyError
            case .invalidContext:
                throw OpenFeatureError.invalidContextError
            case .flagNotFound:
                throw OpenFeatureError.flagNotFoundError(key: self.errorMessage ?? "unknown key")
            case .evaluationError:
                throw OpenFeatureError.generalError(message: self.errorMessage ?? "unknown error")
            case .typeMismatch:
                throw OpenFeatureError.typeMismatchError
            }
        }
        return ProviderEvaluation(
            value: self.value,
            variant: self.variant,
            reason: self.reason.rawValue,
            errorCode: nil,
            errorMessage: nil
        )
    }
}
