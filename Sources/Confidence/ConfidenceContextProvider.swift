import Foundation

/**
A Contextual implementer returns the current context
*/
public protocol ConfidenceContextProvider {
    func getContext() -> ConfidenceStruct
}
