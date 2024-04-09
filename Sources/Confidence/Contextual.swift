import Foundation

/// A Contextual implementer maintains context data and can create child instances
/// that can still access their parent's data
public protocol Contextual {
    var context: ConfidenceStruct { get set }

    func updateContextEntry(key: String, value: ConfidenceValue)
    func removeContextEntry(key: String)
    func clearContext()
    /// Creates a child Contextual instance that still has access
    /// to its parent context
    func withContext(_ context: ConfidenceStruct) -> Self
}
