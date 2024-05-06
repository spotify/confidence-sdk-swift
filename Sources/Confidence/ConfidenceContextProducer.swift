import Foundation
import Combine

public protocol ConfidenceContextProducer {
    func produceContexts() -> AnyPublisher<ConfidenceStruct, Never>
}
