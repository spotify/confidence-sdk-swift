import Foundation

/**
Sends events to Confidence. Contextual data is appended to each event
*/
public protocol ConfidenceEventSender: ConfidenceContextProvider {
    /**
    Upon return, the event has been correctly stored and will be emitted to the backend
    according to the configured flushing logic
    */
    func track(eventName: String, data: ConfidenceStruct) throws
    /**
    The ConfidenceProducer can be used to push context changes or event tracking
    */
    func track(producer: ConfidenceProducer) throws

    /**
    Schedule a manual flush of the event data currently stored on disk
    */
    func flush()
    /**
    Adds/override entry to local context data
    */
    func putContext(key: String, value: ConfidenceValue) async
    /**
    Removes entry from localcontext data
    It hides entries with this key from parents' data (without modifying parents' data)
    */
    func removeKey(key: String) async
    /**
    Creates a child event sender instance that maintains access to its parent's data
    */
    func withContext(_ context: ConfidenceStruct) -> ConfidenceEventSender
}
