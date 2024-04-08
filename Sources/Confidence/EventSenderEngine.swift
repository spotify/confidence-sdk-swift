import Combine
import Foundation

protocol EventsUploader {
    func upload(request: EventBatchRequest) -> Bool
}

struct Event: Codable, Equatable {
    let name: String
}

protocol FlushPolicy {
    func reset()
    func hit(event: Event)
    func shouldFlush() -> Bool
}

protocol Clock {
    func now() -> Date
}

protocol EventSenderEngine {
    func send(name: String)
    func shutdown()
}

final class EventSenderEngineImpl: EventSenderEngine {
    private let SEND_SIG: String = "FLUSH"
    private let storage: any EventStorage
    private let writeReqChannel = PassthroughSubject<Event, Never>()
    private let uploadReqChannel = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()
    private let flushPolicies: [FlushPolicy]
    private let uploader: EventsUploader
    private let clientSecret: String
    private let clock: Clock

    init(
        clientSecret: String,
        uploader: EventsUploader,
        clock: Clock,
        storage: EventStorage,
        flushPolicies: [FlushPolicy]
    ) {
        self.clock = clock
        self.uploader = uploader
        self.clientSecret = clientSecret
        self.storage = storage
        self.flushPolicies = flushPolicies

        writeReqChannel.sink(receiveValue: { [weak self] event in
            guard let self = self else { return }
            do {
                try self.storage.writeEvent(event: event)
            } catch {

            }

            self.flushPolicies.forEach({ policy in policy.hit(event: event) })
            let shouldFlush = self.flushPolicies.contains(where: { policy in policy.shouldFlush() })

            if shouldFlush {
                uploadReqChannel.send(SEND_SIG)
                self.flushPolicies.forEach({ policy in policy.reset() })
            }

        }).store(in: &cancellables)

        uploadReqChannel.sink(receiveValue: { _ in
            do {
                try storage.startNewBatch()
                let ids = storage.batchReadyIds()
                for id in ids {
                    let events = try storage.eventsFrom(id: id)
                    let batchRequest = EventBatchRequest(
                        clientSecret: clientSecret, sendTime: clock.now(), events: events)
                    let shouldCleanup = uploader.upload(request: batchRequest)
                    if shouldCleanup {
                        try storage.remove(id: id)
                    }
                }
            } catch {

            }
        }).store(in: &cancellables)
    }

    func send(name: String) {
        writeReqChannel.send(Event(name: name))
    }

    func shutdown() {
        cancellables.removeAll()
    }
}
