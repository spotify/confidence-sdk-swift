import Foundation

public protocol FlagApplier {
    func apply(flagName: String, resolveToken: String) async
}
