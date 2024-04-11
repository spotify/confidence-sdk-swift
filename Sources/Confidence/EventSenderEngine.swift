import Combine
import Foundation

protocol EventsUploader {
    func upload(request: [Event]) async -> Bool
}

struct Event: Encodable, Equatable {
    let name: String
    let payload: [String: ConfidenceValue]
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
    func send(name: String, message: [String: ConfidenceValue])
    func shutdown()
}

final class EventSenderEngineImpl: EventSenderEngine {
    private static let sendSignalName: String = "FLUSH"
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
                self.uploadReqChannel.send(EventSenderEngineImpl.sendSignalName)
                self.flushPolicies.forEach({ policy in policy.reset() })
            }

        }).store(in: &cancellables)

        uploadReqChannel.sink(receiveValue: { [weak self] _ in
            do {
                guard let self = self else { return }
                try self.storage.startNewBatch()
                let ids = storage.batchReadyIds()
                for id in ids {
                    let events = try self.storage.eventsFrom(id: id)
                    let shouldCleanup = await self.uploader.upload(request: events)
                    if shouldCleanup {
                        try storage.remove(id: id)
                    }
                }
            } catch {

            }
        }).store(in: &cancellables)
    }

    func send(name: String, message: [String: ConfidenceValue]) {
        writeReqChannel.send(Event(name: name, payload: message))
    }

    func shutdown() {
        cancellables.removeAll()
    }
}

private extension Publisher where Self.Failure == Never {
  func sink(receiveValue: @escaping ((Self.Output) async -> Void)) -> AnyCancellable {
    sink { value in
      Task {
        await receiveValue(value)
      }
    }
  }
}
