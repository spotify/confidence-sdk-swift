import Foundation

public protocol Contextual {
    var context: [String: String] { get set } // TODO Introdue complex types

    func updateContextEntry(key: String, value: String)
    func removeContextEntry(key: String)
    func clearContext()

    func withContext(_ context: [String: String]) -> Self
}
