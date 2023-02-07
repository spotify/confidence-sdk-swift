import OpenFeature

public protocol Resolver {
    func resolve(flag: String, ctx: EvaluationContext) throws -> ResolveResult
}

public struct ResolveResult {
    var resolvedValue: ResolvedValue
    var resolveToken: String?
}
