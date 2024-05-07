import Foundation
import Combine

/**
ConfidenceContextProducer or ConfidenceEventProducer
*/
public protocol ConfidenceProducer {
}

public struct Event {
    let name: String
    let message: ConfidenceStruct

    public init(name: String, message: ConfidenceStruct = [:]) {
        self.name = name
        self.message = message
    }
}

/**
ConfidenceContextProducer implementer pushses context changes in a Publisher fashion
*/
public protocol ConfidenceContextProducer: ConfidenceProducer {
    func produceContexts() -> AnyPublisher<ConfidenceStruct, Never>
}

/**
ConfidenceContextProducer implementer emit events in a Publisher fashion
*/
public protocol ConfidenceEventProducer: ConfidenceProducer {
    func produceEvents() -> AnyPublisher<Event, Never>
}
