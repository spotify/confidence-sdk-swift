import Foundation
import Combine

public protocol ConfidenceEventProducer {
    func produceEvents() -> AnyPublisher<Event, Never>
}
