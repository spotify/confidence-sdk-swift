import Combine

class BufferedPassthrough<T> {
    private let subject = PassthroughSubject<T, Never>()
    private var buffer: [T] = []
    private var isListening = false

    func send(_ value: T) {
        if isListening {
            subject.send(value)
        } else {
            buffer.append(value)
        }
    }

    func publisher() -> AnyPublisher<T, Never> {
        isListening = true
        let bufferedPublisher = buffer.publisher
        buffer.removeAll()
        return bufferedPublisher
            .append(subject)
            .eraseToAnyPublisher()
    }
}
