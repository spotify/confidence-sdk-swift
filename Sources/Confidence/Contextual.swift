import Foundation

/**
A Contextual implementer maintains local context data and can create child instances
that can still access their parent's data
Each ConfidenceContextProvider returns local data reconciled with parents' data. Local data has precedence
*/
public protocol Contextual: ConfidenceContextProvider {
    /**
    Adds/override entry to local data
    */
    func putContext(key: String, value: ConfidenceValue)
    /**
    Removes entry from local data
    It hides entries with this key from parents' data (without modifying parents' data)
    */
    func removeKey(key: String)
    /**
    Creates a child Contextual instance that maintains access to its parent's data
    */
    func withContext(_ context: ConfidenceStruct) -> Self
}
