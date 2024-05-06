public protocol Resolver {
    // This throws if the requested flag is not found
    func resolve(flag: String, contextHash: String) throws -> ResolveResult
}

public struct ResolveResult {
    var resolvedValue: ResolvedValue
    var resolveToken: String?
}
