import Foundation

/// Sends events to Confidence. Contextual data is appended to each event
public protocol ConfidenceEventSender: Contextual {
    func track(eventName: String, message: ConfidenceStruct)
}
