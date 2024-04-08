import Foundation
import Combine

protocol EventsUploader {
    func upload(request: EventBatchRequest) -> Bool
}

struct Event: Codable {}

protocol FlushPolicy {
    func reset()
    func hit(event: Event)
    func shouldFlush() -> Bool
}

protocol EventSenderEngine {
    associatedtype T: Codable
    func send(name: String, message: T)
    func shutdown()
}

final class EventSenderEngineImpl<T: Codable>: EventSenderEngine {
    private let SEND_SIG: String = "FLUSH"
    typealias T = T
    private let storage: any EventSenderStorage
    private let writeReqChannel = PassthroughSubject<Event, Never>()
    private let uploadReqChannel = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()
    private let flushPolicies: [FlushPolicy]
    private let uploader: EventsUploader
    private let clientSecret: String

    init(
        clientSecret: String,
        uploader: EventsUploader,
        storage: any EventSenderStorage,
        flushPolicies: [FlushPolicy]
    ) {
        self.uploader = uploader
        self.clientSecret = clientSecret
        self.storage = storage
        self.flushPolicies = flushPolicies

        writeReqChannel.sink(receiveValue: { [weak self] event in
            guard let self = self else { return }
            self.storage.write(event: event)

            self.flushPolicies.forEach({ policy in policy.hit(event: event) })
            let shouldFlush = self.flushPolicies.contains(where: { policy in policy.shouldFlush() })

            if(shouldFlush) {
                uploadReqChannel.send(SEND_SIG)
                self.flushPolicies.forEach({ policy in policy.reset() })
            }

        }).store(in: &cancellables)

        uploadReqChannel.sink(receiveValue: { _ in
            storage.createBatch()
            let paths = storage.batchReadyPaths()

            for path in paths {
                let events = storage.eventBatchForPath(atPath: path)
                let batchRequest = EventBatchRequest(clientSecret: clientSecret, sendTime: Date(), events: events)
                let shouldCleanup = uploader.upload(request: batchRequest)
                if(shouldCleanup) {
                    storage.remove(atPath: path)
                }
            }
            }).store(in: &cancellables)
    }

    func send(name: String, message: T) {
        writeReqChannel.send(Event())
    }

    func shutdown() {
        cancellables.removeAll()
    }
}
