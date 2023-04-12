import Foundation
import OpenFeature

public class ResolverWrapper {
    private let resolver: Resolver
    public var overrides: [String: LocalOverride] = [:]

    public init(resolver: Resolver, overrides: [String: LocalOverride]) {
        self.resolver = resolver
        self.overrides = overrides
    }

    public func errorWrappedResolveFlag<T>(flag: String, defaultValue: T, ctx: EvaluationContext?, errorPrefix: String)
        throws -> (providerEvaluation: ProviderEvaluation<T>, resolveResult: ResolveResult?)
    {
        do {
            return try resolveFlag(flag: flag, defaultValue: defaultValue, ctx: ctx)
        } catch let error {
            if error is OpenFeatureError {
                throw error
            } else {
                throw OpenFeatureError.generalError(message: "\(errorPrefix): \(error)")
            }
        }
    }

    private func resolveFlag<T>(flag: String, defaultValue: T, ctx: EvaluationContext?) throws -> (
        ProviderEvaluation<T>, resolveResult: ResolveResult?
    ) {
        let path = try FlagPath.getPath(for: flag)

        if let overrideValue: (value: T, variant: String?) = getOverride(path: path) {
            return (
                ProviderEvaluation(
                    value: overrideValue.value, variant: overrideValue.variant, reason: Reason.defaultReason.rawValue),
                nil
            )
        }

        guard let ctx = ctx else {
            throw OpenFeatureError.providerNotReady
        }

        do {
            let resolverResult = try self.resolver.resolve(flag: path.flag, ctx: ctx)
            guard let value = resolverResult.resolvedValue.value else {
                return (
                    ProviderEvaluation(value: defaultValue, variant: nil, reason: Reason.defaultReason.rawValue),
                    resolverResult
                )
            }

            let pathValue: Value = try getValue(path: path.path, value: value)
            guard let typedValue: T = pathValue == .null ? defaultValue : pathValue.getTyped() else {
                throw OpenFeatureError.parseError(message: "Unable to parse flag value: \(pathValue)")
            }

            return (
                ProviderEvaluation(
                    value: typedValue,
                    variant: resolverResult.resolvedValue.variant,
                    reason: Reason.targetingMatch.rawValue),
                resolverResult
            )
        } catch KonfidensError.flagIsArchived {
            return (ProviderEvaluation(value: defaultValue, variant: nil, reason: Reason.disabled.rawValue), nil)
        } catch KonfidensError.cachedValueExpired {
            return (ProviderEvaluation(value: defaultValue, variant: nil, reason: Reason.stale.rawValue), nil)
        } catch {
            throw error
        }
    }

    private func getValue(path: [String], value: Value) throws -> Value {
        if path.isEmpty {
            guard case .structure = value else {
                throw OpenFeatureError.parseError(
                    message: "Flag path must contain path to the field for non-object values")
            }
        }

        var pathValue = value
        if !path.isEmpty {
            pathValue = try getValueForPath(path: path, value: value)
        }

        return pathValue
    }

    private func getValueForPath(path: [String], value: Value) throws -> Value {
        var curValue = value
        for field in path {
            guard case .structure(let values) = curValue, let newValue = values[field] else {
                throw OpenFeatureError.generalError(message: "Unable to find key '\(field)'")
            }

            curValue = newValue
        }

        return curValue
    }

    private func getOverride<T>(path: FlagPath) -> (value: T, variant: String?)? {
        let fieldPath = "\(path.flag).\(path.path.joined(separator: "."))"

        guard let overrideValue = self.overrides[fieldPath] ?? self.overrides[path.flag] else {
            return nil
        }

        switch overrideValue {
        case let .flag(_, variant, value):
            guard let pathValue = try? getValue(path: path.path, value: .structure(value)) else {
                return nil
            }
            guard let typedValue: T = pathValue.getTyped() else {
                return nil
            }

            return (typedValue, variant)

        case let .field(_, variant, value):
            guard let typedValue: T = value.getTyped() else {
                return nil
            }

            return (typedValue, variant)
        }
    }
}
