import Foundation

public protocol ConfidenceEventSender: Contextual {
    func send(eventName: String)
}
