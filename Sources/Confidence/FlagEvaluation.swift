import Foundation

public struct Evaluation<T> {
    public let value: T
    public let variant: String?
    public let reason: ResolveReason
    public let errorCode: ErrorCode?
    public let errorMessage: String?
}

public enum ErrorCode: Equatable {
    case providerNotReady
    case invalidContext
    case flagNotFound
    case evaluationError
    case parseError(message: String)
    case typeMismatch(message: String = "Mismatch between default value and flag value type")
    case generalError(message: String)
}

struct FlagResolution: Encodable, Decodable, Equatable {
    let context: ConfidenceStruct
    let flags: [ResolvedValue]
    let resolveToken: String
    static let EMPTY = FlagResolution(context: [:], flags: [], resolveToken: "")
}

extension FlagResolution {
    // swiftlint:disable function_body_length
    // swiftlint:disable cyclomatic_complexity
    func evaluate<T>(
        flagName: String,
        defaultValue: T,
        context: ConfidenceStruct,
        flagApplier: FlagApplier? = nil,
        debugLogger: DebugLogger? = nil
    ) -> Evaluation<T> {
        do {
            let parsedKey = try FlagPath.getPath(for: flagName)
            let resolvedFlag = self.flags.first { resolvedFlag in resolvedFlag.flag == parsedKey.flag }
            guard let resolvedFlag = resolvedFlag else {
                return Evaluation(
                    value: defaultValue,
                    variant: nil,
                    reason: .error,
                    errorCode: .flagNotFound,
                    errorMessage: "Flag '\(parsedKey.flag)' not found in local cache"
                )
            }

            if let debugLogger = debugLogger {
                debugLogger.logResolveDebugURL(flagName: parsedKey.flag, context: context)
            }

            if let evaluation = checkBackendErrors(resolvedFlag: resolvedFlag, defaultValue: defaultValue) {
                return evaluation
            }

            guard let value = resolvedFlag.value else {
                // No backend error, but nil value returned. This can happend with "noSegmentMatch" or "archived", for example
                Task {
                    if resolvedFlag.shouldApply {
                        await flagApplier?.apply(flagName: parsedKey.flag, resolveToken: self.resolveToken)
                    }
                }
                return Evaluation(
                    value: defaultValue,
                    variant: resolvedFlag.variant,
                    reason: resolvedFlag.resolveReason,
                    errorCode: nil,
                    errorMessage: nil
                )
            }

            let parsedValue = try getValueForPath(path: parsedKey.path, value: value)
            let typedValue: T? = try getTyped(value: parsedValue, defaultValue: defaultValue)

            if resolvedFlag.resolveReason == .match {
                var resolveReason: ResolveReason = .match
                if self.context != context {
                    resolveReason = .stale
                }
                if let typedValue = typedValue {
                    Task {
                        if resolvedFlag.shouldApply {
                            await flagApplier?.apply(flagName: parsedKey.flag, resolveToken: self.resolveToken)
                        }
                    }
                    return Evaluation(
                        value: typedValue,
                        variant: resolvedFlag.variant,
                        reason: resolveReason,
                        errorCode: nil,
                        errorMessage: nil
                    )
                } else {
                    // `null` type from backend instructs to use client-side default value
                    if parsedValue == .init(null: ()) {
                        Task {
                            if resolvedFlag.shouldApply {
                                await flagApplier?.apply(flagName: parsedKey.flag, resolveToken: self.resolveToken)
                            }
                        }
                        return Evaluation(
                            value: defaultValue,
                            variant: resolvedFlag.variant,
                            reason: resolveReason,
                            errorCode: nil,
                            errorMessage: nil
                        )
                    } else {
                        return Evaluation(
                            value: defaultValue,
                            variant: nil,
                            reason: .error,
                            errorCode: .typeMismatch(),
                            errorMessage: nil
                        )
                    }
                }
            } else {
                Task {
                    if resolvedFlag.shouldApply {
                        await flagApplier?.apply(flagName: parsedKey.flag, resolveToken: self.resolveToken)
                    }
                }
                return Evaluation(
                    value: defaultValue,
                    variant: resolvedFlag.variant,
                    reason: resolvedFlag.resolveReason,
                    errorCode: nil,
                    errorMessage: nil
                )
            }
        } catch let error as ConfidenceError {
            return Evaluation(
                value: defaultValue,
                variant: nil,
                reason: .error,
                errorCode: error.errorCode,
                errorMessage: error.description
            )
        } catch {
            return Evaluation(
                value: defaultValue,
                variant: nil,
                reason: .error,
                errorCode: .evaluationError,
                errorMessage: error.localizedDescription
            )
        }
    }
    // swiftlint:enable function_body_length
    // swiftlint:enable cyclomatic_complexity

    private func checkBackendErrors<T>(resolvedFlag: ResolvedValue, defaultValue: T) -> Evaluation<T>? {
        if resolvedFlag.resolveReason == .targetingKeyError {
            return Evaluation(
                value: defaultValue,
                variant: nil,
                reason: .targetingKeyError,
                errorCode: .invalidContext,
                errorMessage: "Invalid targeting key"
            )
        } else if resolvedFlag.resolveReason == .error ||
        resolvedFlag.resolveReason == .unknown ||
        resolvedFlag.resolveReason == .unspecified {
            return Evaluation(
                value: defaultValue,
                variant: nil,
                reason: .error,
                errorCode: .evaluationError,
                errorMessage: "Unknown error from backend"
            )
        } else {
            return nil
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func getTyped<T>(value: ConfidenceValue, defaultValue: T) throws -> T? {
        if let value = self as? T {
            return value
        }

        let result: Any?
        switch value.type() {
        case .boolean:
            result = value.asBoolean()
        case .string:
            result = value.asString()
        case .integer:
            if T.self == Int32.self, let intValue = value.asInteger() {
                result = Int32(intValue)
            } else if T.self == Int64.self, let intValue = value.asInteger() {
                result = Int64(intValue)
            } else {
                result = value.asInteger()
            }
        case .double:
            result = value.asDouble()
        case .date:
            result = value.asDate()
        case .timestamp:
            result = value.asDateComponents()
        // TODO We should align List and Structure to return the same data type - asListNative?
        case .list:
            result = value.asList()
        case .structure:
            result = try handleStructureValue(value: value, defaultValue: defaultValue)
        case .null:
            return nil
        }

        if let typedResult = result as? T {
            return typedResult
        } else {
            throw ConfidenceError.typeMismatch(message: "Value \(value) cannot be cast to \(T.self)")
        }
    }

    private func handleStructureValue<T>(value: ConfidenceValue, defaultValue: T) throws -> [String: Any] {
        guard let defaultDict = defaultValue as? [String: Any] else {
            throw ConfidenceError
                .typeMismatch(
                    message: "Expected a Dictionary as default value, but got a different type"
                )
        }
        guard let structure = value.asStructure() else {
            throw ConfidenceError
                .typeMismatch(
                    message: "Unexpected error with internal ConfidenceStruct conversion"
                )
        }
        try validateDictionaryStructureCompatibility(
            structure: structure,
            defaultDict: defaultDict
        )
        // Filter only the entries in the original default value
        var filteredNative: [String: Any] = [:]
        for requiredKey in defaultDict.keys {
            if let confidenceValue = structure[requiredKey] {
                // If the resolved value is null, use the default value instead
                if confidenceValue.isNull() {
                    filteredNative[requiredKey] = defaultDict[requiredKey]
                } else {
                    filteredNative[requiredKey] = confidenceValue.asNative()
                }
            }
        }
        return filteredNative
    }

    private func validateDictionaryStructureCompatibility(
        structure: ConfidenceStruct,
        defaultDict: [String: Any]
    ) throws {
        for defaultValueKey in defaultDict.keys {
            guard let confidenceValue = structure[defaultValueKey] else {
                throw ConfidenceError.typeMismatch(
                    message: "Default value key '\(defaultValueKey)' not found in flag"
                )
            }

            // If the resolved value is null, it's compatible with any type (we'll use default value)
            if confidenceValue.isNull() {
                continue
            }

            let defaultValueValue: Any? = defaultDict[defaultValueKey]
            if !isValueCompatibleWithDefaultValue(
                confidenceType: confidenceValue.type(),
                defaultValue: defaultValueValue
            ) {
                let message = "Default value key '\(defaultValueKey)' has incompatible type. " +
                    "Expected from flag is '\(getIntrinsicType(of: defaultValueValue))', " +
                    "got '\(confidenceValue.type())'"
                throw ConfidenceError.typeMismatch(message: message)
            }
        }
    }

    private func getIntrinsicType(of value: Any?) -> String {
        if let unwrapped = value {
            return "\(type(of: unwrapped))"
        } else {
            return "nil"
        }
    }

    private func isValueCompatibleWithDefaultValue(
        confidenceType: ConfidenceValueType,
        defaultValue: Any?
    ) -> Bool {
        switch defaultValue {
        case is String:
            return confidenceType == .string
        case is Int, is Int32, is Int64:
            return confidenceType == .integer
        case is Double, is Float:
            return confidenceType == .double
        case is Bool:
            return confidenceType == .boolean
        case is Date:
            return confidenceType == .timestamp
        case is DateComponents:
            return confidenceType == .date
        case is Array<Any>:
            return confidenceType == .list
        case is [String: Any]:
            return confidenceType == .structure
        case .none: // TODO This requires extra care
            return confidenceType == .null
        default:
            return false
        }
    }

    private func getValueForPath(path: [String], value: ConfidenceValue) throws -> ConfidenceValue {
        var curValue = value
        for step in path {
            guard let values = curValue.asStructure(), let newValue = values[step] else {
                throw ConfidenceError.internalError(message: "Unable to find key '\(step)'")
            }
            curValue = newValue
        }
        return curValue
    }
}
