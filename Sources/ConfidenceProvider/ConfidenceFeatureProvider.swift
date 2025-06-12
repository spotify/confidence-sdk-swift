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
        guard let nativeDefault = defaultValue.asNativeDictionary() else {
            throw OpenFeatureError.generalError(message: "Unexpected error handling the default value")
        }
        let evaluation = confidence.getEvaluation(key: key, defaultValue: nativeDefault)
        return try evaluation.toProviderEvaluationWithValueConversion()
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
    private func throwIfError() throws {
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
            reason: Reason.targetingMatch.rawValue, // TODO VERIFY THIS!
            errorCode: nil,
            errorMessage: nil
        )
    }
}

extension Evaluation where T == [String: Any] {
    func toProviderEvaluationWithValueConversion() throws -> ProviderEvaluation<OpenFeature.Value> {
        try throwIfError()
        let openFeatureValue = OpenFeature.Value.fromNativeDictionary(self.value)
        return ProviderEvaluation(
            value: openFeatureValue,
            variant: self.variant,
            reason: Reason.targetingMatch.rawValue, // TODO VERIFY THIS!
            errorCode: nil,
            errorMessage: nil
        )
    }
}

extension OpenFeature.Value {
    /// Converts an OpenFeature Value to a Dictionary of native Swift types.
    ///
    /// - Returns: A dictionary where keys are Strings and values are native Swift types:
    ///   - Bool for boolean values
    ///   - String for string values
    ///   - Int64 for integer values
    ///   - Double for double values
    ///   - Date for date values
    ///   - [Any] for list values (recursively converted)
    ///   - [String: Any] for nested structure values (recursively converted)
    ///   - NSNull for null values
    /// - Returns: nil if the Value is not a structure type
    public func asNativeDictionary() -> [String: Any]? {
        guard case let .structure(valueMap) = self else {
            return nil
        }

        return valueMap.mapValues { value in
            return value.asNativeType()
        }
    }

    /// Converts an OpenFeature Value to its corresponding native Swift type.
    ///
    /// - Returns: The native Swift representation:
    ///   - Bool for boolean values
    ///   - String for string values
    ///   - Int64 for integer values
    ///   - Double for double values
    ///   - Date for date values
    ///   - [Any] for list values (recursively converted)
    ///   - [String: Any] for structure values (recursively converted)
    ///   - NSNull for null values
    public func asNativeType() -> Any {
        switch self {
        case .boolean(let value):
            return value
        case .string(let value):
            return value
        case .integer(let value):
            return value
        case .double(let value):
            return value
        case .date(let value):
            return value
        case .list(let values):
            return values.map { $0.asNativeType() }
        case .structure(let valueMap):
            return valueMap.mapValues { $0.asNativeType() }
        case .null:
            return NSNull()
        }
    }

    /// Creates an OpenFeature Value from a native Swift dictionary.
    ///
    /// - Parameter dictionary: A dictionary with String keys and Any values
    /// - Returns: An OpenFeature Value structure containing the converted dictionary
    public static func fromNativeDictionary(_ dictionary: [String: Any]) -> OpenFeature.Value {
        let convertedMap = dictionary.mapValues { value in
            return fromNativeType(value)
        }
        return .structure(convertedMap)
    }

    /// Creates an OpenFeature Value from a native Swift type.
    ///
    /// - Parameter value: The native Swift value to convert
    /// - Returns: The corresponding OpenFeature Value
    public static func fromNativeType(_ value: Any) -> OpenFeature.Value {
        // Handle numeric types first
        if let boolValue = value as? Bool {
            return .boolean(boolValue)
        }
        if let stringValue = value as? String {
            return .string(stringValue)
        }

        // Handle integer types
        if let intValue = value as? Int {
            return .integer(Int64(intValue))
        }
        if let int64Value = value as? Int64 {
            return .integer(int64Value)
        }
        if let int32Value = value as? Int32 {
            return .integer(Int64(int32Value))
        }

        // Handle floating point types
        if let doubleValue = value as? Double {
            return .double(doubleValue)
        }
        if let floatValue = value as? Float {
            return .double(Double(floatValue))
        }

        // Handle other types
        return handleOtherNativeTypes(value)
    }

    private static func handleOtherNativeTypes(_ value: Any) -> OpenFeature.Value {
        if let dateValue = value as? Date {
            return .date(dateValue)
        }
        if let arrayValue = value as? [Any] {
            let convertedArray = arrayValue.map { fromNativeType($0) }
            return .list(convertedArray)
        }
        if let dictValue = value as? [String: Any] {
            let convertedDict = dictValue.mapValues { fromNativeType($0) }
            return .structure(convertedDict)
        }
        if value is NSNull {
            return .null
        }
        // For unknown types, convert to string representation
        return .string(String(describing: value))
    }
}
