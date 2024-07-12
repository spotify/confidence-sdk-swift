import Foundation
import Combine

/**
ConfidenceContextProducer or ConfidenceEventProducer
*/
public protocol ConfidenceProducer {
}

public struct Event {
    let name: String
    let data: ConfidenceStruct
    let shouldFlush: Bool

    public init(name: String, data: ConfidenceStruct = [:], shouldFlush: Bool = false) {
        self.name = name
        self.data = data
        self.shouldFlush = shouldFlush
    }
}

/**
ConfidenceContextProducer implementer pushses context changes in a Publisher fashion
*/
public protocol ConfidenceContextProducer: ConfidenceProducer {
    /**
    Publish context data.
    */
    func produceContexts() -> AnyPublisher<ConfidenceStruct, Never>
}

/**
ConfidenceContextProducer implementer emit events in a Publisher fashion
*/
public protocol ConfidenceEventProducer: ConfidenceProducer {
    /**
    Publish events.
    */
    func produceEvents() -> AnyPublisher<Event, Never>
}
