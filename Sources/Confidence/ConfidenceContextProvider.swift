import Foundation

/**
A Contextual implementer returns the current context
*/
public protocol ConfidenceContextProvider {
    /**
    Returns the current context, including the ancestors' context data
    */
    func getContext() -> ConfidenceStruct
}
