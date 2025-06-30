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
        let removedKeys: [String] = oldContext.map { oldCtx in
        let oldKeys = Array(oldCtx.asMap().keys)
        let newKeys = Set(newContext.asMap().keys)
        return oldKeys.filter { !newKeys.contains($0) }
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
        switch defaultValue {
        case .structure:
            guard let nativeDefault = defaultValue.asNativeDictionary() else {
                throw OpenFeatureError.generalError(message: "Unexpected error handling the default value")
            }
            let evaluation = confidence.getEvaluation(key: key, defaultValue: nativeDefault)
            return try evaluation.toProviderEvaluationWithValueConversion()
        case .list(let values):
            let nativeDefault = values.map { $0.asNativeType() }
            return try confidence.getEvaluation(
                key: key,
                defaultValue: nativeDefault)
            .toProviderEvaluationWithValueConversion()
        default:
            throw OpenFeatureError.generalError(message: "Unexpected default value type: must be Dictionary or Array")
        }
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
    /// Throws an OpenFeature error if this evaluation contains an error code
    internal func throwIfError() throws {
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
            case .parseError(message: let message):
                throw OpenFeatureError.parseError(message: message)
            case .generalError(message: let message):
                throw OpenFeatureError.generalError(message: message)
            }
        }
    }

    func toProviderEvaluation() throws -> ProviderEvaluation<T> {
        try throwIfError()
        return ProviderEvaluation(
            value: self.value,
            variant: self.variant,
            reason: self.reason.rawValue,
            errorCode: nil,
            errorMessage: nil
        )
    }
}

extension Evaluation where T == [String: Any] {
    func toProviderEvaluationWithValueConversion() throws -> ProviderEvaluation<OpenFeature.Value> {
        try throwIfError()
        let openFeatureValue = try OpenFeature.Value.fromNativeDictionary(self.value)
        return ProviderEvaluation(
            value: openFeatureValue,
            variant: self.variant,
            reason: self.reason.rawValue,
            errorCode: nil,
            errorMessage: nil
        )
    }
}

extension Evaluation where T == [Any] {
    func toProviderEvaluationWithValueConversion() throws -> ProviderEvaluation<OpenFeature.Value> {
        try throwIfError()
        let openFeatureValue = try OpenFeature.Value.fromNativeType(self.value)
        return ProviderEvaluation(
            value: openFeatureValue,
            variant: self.variant,
            reason: self.reason.rawValue,
            errorCode: nil,
            errorMessage: nil
        )
    }
}
