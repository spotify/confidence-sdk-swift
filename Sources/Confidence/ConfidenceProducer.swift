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
    let shouldFlush: Bool

    public init(name: String, message: ConfidenceStruct = [:], shouldFlush: Bool = false) {
        self.name = name
        self.message = message
        self.shouldFlush = shouldFlush
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
