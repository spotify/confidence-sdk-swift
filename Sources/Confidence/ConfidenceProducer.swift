import Foundation
import Combine

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

public protocol ConfidenceContextProducer {
    func produceContexts() -> AnyPublisher<ConfidenceStruct, Never>
}

public protocol ConfidenceEventProducer: ConfidenceProducer {
    func produceEvents() -> AnyPublisher<Event, Never>
}
