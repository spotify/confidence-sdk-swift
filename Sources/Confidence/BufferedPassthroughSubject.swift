import Foundation
import Combine

class BufferedPassthrough<T> {
    private let subject = PassthroughSubject<T, Never>()
    private var buffer: [T] = []
    private var isListening = false
    private let queue = DispatchQueue(label: "com.confidence.passthrough_serial")

    func send(_ value: T) {
        queue.sync {
            if isListening {
                subject.send(value)
            } else {
                buffer.append(value)
            }
        }
    }

    func publisher() -> AnyPublisher<T, Never> {
        return queue.sync {
            isListening = true
            let bufferedPublisher = buffer.publisher
            buffer.removeAll()
            return bufferedPublisher
                .append(subject)
                .eraseToAnyPublisher()
        }
    }
}
