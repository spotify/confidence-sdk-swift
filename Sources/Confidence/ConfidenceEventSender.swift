import Foundation

/**
Sends events to Confidence. Contextual data is appended to each event
*/
public protocol ConfidenceEventSender: Contextual {
    /**
    Upon return, the event has been correctly stored and will be emitted to the backend
    according to the configured flushing logic
    */
    func track(eventName: String, message: ConfidenceStruct)
    /**
    The ConfidenceProducer can be used to push context changes or event tracking
    */
    func track(producer: ConfidenceProducer)
}
