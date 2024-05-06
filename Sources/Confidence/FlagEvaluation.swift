import Foundation

public struct Evaluation<T> {
    public let value: T
    public let variant: String?
    public let reason: ResolveReason
    public let errorCode: ErrorCode?
    public let errorMessage: String?
}

public enum ErrorCode {
    case providerNotReady
    case invalidContext
}

struct FlagResolution: Encodable, Decodable, Equatable {
    let context: ConfidenceStruct
    let flags: [ResolvedValue]
    let resolveToken: String
    static let EMPTY = FlagResolution(context: [:], flags: [], resolveToken: "")
}

extension FlagResolution {
    func evaluate<T>(
        flagName: String,
        defaultValue: T,
        context: ConfidenceStruct,
        flagApplier: FlagApplier? = nil
    ) throws -> Evaluation<T> {
        let parsedKey = try FlagPath.getPath(for: flagName)
        if self == FlagResolution.EMPTY {
            throw ConfidenceError.flagNotFoundError(key: parsedKey.flag)
        }
        let resolvedFlag = self.flags.first { resolvedFlag in  resolvedFlag.flag == parsedKey.flag }
        guard let resolvedFlag = resolvedFlag else {
            throw ConfidenceError.flagNotFoundError(key: parsedKey.flag)
        }

        if resolvedFlag.resolveReason != .targetingKeyError {
            Task {
                await flagApplier?.apply(flagName: parsedKey.flag, resolveToken: self.resolveToken)
            }
        } else {
            return Evaluation(
                value: defaultValue,
                variant: nil,
                reason: .targetingKeyError,
                errorCode: .invalidContext,
                errorMessage: "Invalid targeting key"
            )
        }

        guard let value = resolvedFlag.value else {
            return Evaluation(
                value: defaultValue,
                variant: resolvedFlag.variant,
                reason: resolvedFlag.resolveReason,
                errorCode: nil,
                errorMessage: nil
            )
        }

        let parsedValue = try getValue(path: parsedKey.path, value: value)
        let pathValue: T = getTyped(value: parsedValue) ?? defaultValue

        if resolvedFlag.resolveReason == .match {
            var resolveReason: ResolveReason = .match
            if self.context != context {
                resolveReason = .stale
            }
            return Evaluation(
                value: pathValue,
                variant: resolvedFlag.variant,
                reason: resolveReason,
                errorCode: nil,
                errorMessage: nil
            )
        } else {
            return Evaluation(
                value: defaultValue,
                variant: resolvedFlag.variant,
                reason: resolvedFlag.resolveReason,
                errorCode: nil,
                errorMessage: nil
            )
        }
    }

    private func getTyped<T>(value: ConfidenceValue) -> T? {
        if let value = self as? T {
            return value
        }

        switch value.type() {
        case .boolean:
            return value.asBoolean() as? T
        case .string:
            return value.asString() as? T
        case .integer:
            return value.asInteger() as? T
        case .double:
            return value.asDouble() as? T
        case .date:
            return value.asDate() as? T
        case .timestamp:
            return value.asDateComponents() as? T
        case .list:
            return value.asList() as? T
        case .structure:
            return value.asStructure() as? T
        case .null:
            return nil
        }
    }

    private func getValue(path: [String], value: ConfidenceValue) throws -> ConfidenceValue {
        if path.isEmpty {
            guard value.asStructure() != nil else {
                throw ConfidenceError.parseError(
                    message: "Flag path must contain path to the field for non-object values")
            }
        }

        var pathValue = value
        if !path.isEmpty {
            pathValue = try getValueForPath(path: path, value: value)
        }

        return pathValue
    }

    private func getValueForPath(path: [String], value: ConfidenceValue) throws -> ConfidenceValue {
        var curValue = value
        for field in path {
            guard let values = curValue.asStructure(), let newValue = values[field] else {
                throw ConfidenceError.internalError(message: "Unable to find key '\(field)'")
            }

            curValue = newValue
        }

        return curValue
    }
}
