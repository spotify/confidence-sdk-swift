import Foundation

public protocol FlagApplier: Sendable {
    func apply(flagName: String, resolveToken: String) async
}
