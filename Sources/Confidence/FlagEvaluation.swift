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

    private func swiftTypeToConfidenceType(_ type: Any.Type) -> ConfidenceValueType {
        if type == String.self { return .string }
        if type == Int.self || type == Int32.self || type == Int64.self { return .integer }
        if type == Double.self || type == Float.self { return .double }
        if type == Bool.self { return .boolean }
        if type == Date.self { return .timestamp }
        if type == DateComponents.self { return .date }
        if type == Array<Any>.self { return .list }
        if type == Dictionary<String, Any>.self { return .structure }
        return .null
    }

    private func checkListElementTypeCompatibility(
        defaultList: [Any],
        resolvedList: [ConfidenceValue],
        errorContext: String? = nil
    ) throws {
        guard !defaultList.isEmpty && !resolvedList.isEmpty else { return }

        let defaultElementType = type(of: defaultList[0])
        let resolvedElementType = resolvedList[0].type()
        let defaultElementConfidenceType = swiftTypeToConfidenceType(defaultElementType)

        guard resolvedElementType == defaultElementConfidenceType else {
            let message = buildTypeMismatchMessage(
                expected: defaultElementConfidenceType,
                actual: resolvedElementType,
                context: errorContext
            )
            throw ConfidenceError.typeMismatch(message: message)
        }
    }

    private func buildTypeMismatchMessage(
        expected: ConfidenceValueType,
        actual: ConfidenceValueType,
        context: String?
    ) -> String {
        if let context = context {
            return "Default value key '\(context)' has incompatible list element type. " +
                "Expected element type '\(expected)', got '\(actual)'"
        } else {
            return "List has incompatible element type. Expected \(expected), got \(actual)"
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
        case .list:
            if let defaultList = defaultValue as? [Any], let resolvedList = value.asList() {
                try checkListElementTypeCompatibility(
                    defaultList: defaultList,
                    resolvedList: resolvedList
                )
            }
            result = value.asNative()
        case .structure:
            if let defaultStruct = defaultValue as? ConfidenceStruct,
                let resolvedStruct = value.asStructure() {
                result = StructMerger.mergeStructWithDefault(
                    resolved: resolvedStruct,
                    defaultStruct: defaultStruct
                ) as? T
            } else if let defaultDict = defaultValue as? [String: Any],
                let resolvedStruct = value.asStructure() {
                result = StructMerger.mergeDictionaryWithDefault(
                    resolved: resolvedStruct,
                    defaultDict: defaultDict)
            } else {
                throw ConfidenceError.typeMismatch(
                    message: "Expected ConfidenceStruct or Dictionary as default value")
            }
        case .null:
            return nil
        }

        if let typedResult = result as? T {
            return typedResult
        } else {
            throw ConfidenceError.typeMismatch(message: "Value \(value) cannot be cast to \(T.self)")
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
