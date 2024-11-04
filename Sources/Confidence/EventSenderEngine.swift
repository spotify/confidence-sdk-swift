import Combine
import Foundation

protocol FlushPolicy {
    func reset()
    func hit(event: ConfidenceEvent)
    func shouldFlush() -> Bool
}

protocol EventSenderEngine {
    func emit(
        eventName: String,
        data: ConfidenceStruct,
        context: ConfidenceStruct
    ) throws
    func shutdown()
    func flush()
}

final class EventSenderEngineImpl: EventSenderEngine {
    private static let sendSignalName: String = "FLUSH"
    private let storage: any EventStorage
    private let writeReqChannel = PassthroughSubject<ConfidenceEvent, Never>()
    private let uploadReqChannel = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()
    private let flushPolicies: [FlushPolicy]
    private let uploader: ConfidenceClient
    private let clientSecret: String
    private let payloadMerger: PayloadMerger = PayloadMergerImpl()
    private let semaphore = DispatchSemaphore(value: 1)
    private let writeQueue: DispatchQueue
    private let debugLogger: DebugLogger?

    convenience init(
        clientSecret: String,
        uploader: ConfidenceClient,
        storage: EventStorage,
        debugLogger: DebugLogger?
    ) {
        self.init(
            clientSecret: clientSecret,
            uploader: uploader,
            storage: storage,
            flushPolicies: [SizeFlushPolicy(batchSize: 10)],
            writeQueue: DispatchQueue(label: "ConfidenceWriteQueue"),
            debugLogger: debugLogger
        )
    }

    init(
        clientSecret: String,
        uploader: ConfidenceClient,
        storage: EventStorage,
        flushPolicies: [FlushPolicy],
        writeQueue: DispatchQueue,
        debugLogger: DebugLogger?
    ) {
        self.uploader = uploader
        self.clientSecret = clientSecret
        self.storage = storage
        self.flushPolicies = flushPolicies + [ManualFlushPolicy()]
        self.writeQueue = writeQueue
        self.debugLogger = debugLogger

        writeReqChannel
            .receive(on: self.writeQueue)
            .sink { [weak self] event in
                guard let self = self else { return }
                if event.name != manualFlushEvent.name { // skip storing flush events.
                    do {
                        try self.storage.writeEvent(event: event)
                    } catch {
                    }
                }
                self.flushPolicies.forEach { policy in policy.hit(event: event) }
                let shouldFlush = self.flushPolicies.contains { policy in policy.shouldFlush() }

                if shouldFlush {
                    self.uploadReqChannel.send(EventSenderEngineImpl.sendSignalName)
                    self.flushPolicies.forEach { policy in policy.reset() }
                }
            }
            .store(in: &cancellables)

        uploadReqChannel.sink { [weak self] _ in
            guard let self = self else { return }
            await self.upload()
        }
        .store(in: &cancellables)
    }

    func upload() async {
        await withSemaphore { [weak self] in
            guard let self = self else { return }
            do {
                try self.storage.startNewBatch()
                let ids = try storage.batchReadyIds()
                if ids.isEmpty {
                    return
                }
                for id in ids {
                    let events: [NetworkEvent] = try self.storage.eventsFrom(id: id)
                        .compactMap { event in
                            return NetworkEvent(
                                eventDefinition: event.name,
                                payload: NetworkStruct(fields: TypeMapper.convert(structure: event.payload).fields),
                                eventTime: Date.backport.toISOString(date: event.eventTime))
                        }
                    var shouldCleanup = false
                    if events.isEmpty {
                        shouldCleanup = true
                    } else {
                        shouldCleanup = try await self.uploader.upload(events: events)
                    }

                    if shouldCleanup {
                        try storage.remove(id: id)
                    }
                }
            } catch {
            }
        }
    }

    func withSemaphore(callback: @escaping () async -> Void) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                self.semaphore.wait()
                continuation.resume()
            }
        }
        await callback()
        semaphore.signal()
    }

    func emit(
        eventName: String,
        data: ConfidenceStruct,
        context: ConfidenceStruct
    ) throws {
        let event = ConfidenceEvent(
            name: eventName,
            payload: try payloadMerger.merge(context: context, data: data),
            eventTime: Date.backport.now)
        writeReqChannel.send(event)
        debugLogger?.logEvent(action: "Emitting event", event: event)
    }

    func flush() {
        writeReqChannel.send(manualFlushEvent)
        debugLogger?.logEvent(action: "Event flushed", event: nil)
    }

    func shutdown() {
        for cancellable in cancellables {
            cancellable.cancel()
        }
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
