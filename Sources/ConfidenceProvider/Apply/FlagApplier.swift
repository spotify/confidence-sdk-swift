import Foundation

public protocol FlagAppier {
    func apply(flagName: String, resolveToken: String)
}
