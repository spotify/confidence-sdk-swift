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
    static let defaultFlushInterval: TimeInterval = 60
    private static let sendSignalName: String = "FLUSH"
    private static let defaultShutdownTimeout: TimeInterval = 10
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
    private let shutdownTimeout: TimeInterval
    private var flushIntervalTimer: DispatchSourceTimer?
    private let shutdownLock = NSLock()
    private var isShutdown = false

    convenience init(
        clientSecret: String,
        uploader: ConfidenceClient,
        storage: EventStorage,
        debugLogger: DebugLogger?,
        flushInterval: TimeInterval = EventSenderEngineImpl.defaultFlushInterval
    ) {
        self.init(
            clientSecret: clientSecret,
            uploader: uploader,
            storage: storage,
            flushPolicies: [SizeFlushPolicy(batchSize: 10)],
            writeQueue: DispatchQueue(label: "ConfidenceWriteQueue"),
            debugLogger: debugLogger,
            flushInterval: flushInterval
        )
    }

    init(
        clientSecret: String,
        uploader: ConfidenceClient,
        storage: EventStorage,
        flushPolicies: [FlushPolicy],
        writeQueue: DispatchQueue,
        debugLogger: DebugLogger?,
        flushInterval: TimeInterval = EventSenderEngineImpl.defaultFlushInterval,
        shutdownTimeout: TimeInterval = EventSenderEngineImpl.defaultShutdownTimeout
    ) {
        self.uploader = uploader
        self.clientSecret = clientSecret
        self.storage = storage
        self.flushPolicies = flushPolicies + [ManualFlushPolicy()]
        self.writeQueue = writeQueue
        self.debugLogger = debugLogger
        self.shutdownTimeout = shutdownTimeout

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
            await self.upload(sealCurrentBatch: true)
        }
        .store(in: &cancellables)

        if flushInterval > 0 {
            startFlushIntervalTimer(flushInterval)
        }

        do {
            try storage.startNewBatch()
        } catch {
        }
        Task {
            await self.upload(sealCurrentBatch: false)
        }
    }

    func upload(sealCurrentBatch: Bool = true) async {
        await withSemaphore { [weak self] in
            guard let self = self else { return }
            do {
                if sealCurrentBatch {
                    try self.storage.startNewBatch()
                }
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

        shutdownLock.lock()
        guard !isShutdown else {
            shutdownLock.unlock()
            debugLogger?.logMessage(
                message: "Event '\(eventName)' dropped: engine is shut down",
                isWarning: true
            )
            return
        }
        writeReqChannel.send(event)
        shutdownLock.unlock()

        debugLogger?.logEvent(action: "Emitting event", event: event)
    }

    func flush() {
        writeReqChannel.send(manualFlushEvent)
        debugLogger?.logEvent(action: "Event flushed", event: nil)
    }

    func shutdown() {
        shutdownLock.lock()
        guard !isShutdown else {
            shutdownLock.unlock()
            return
        }
        isShutdown = true
        shutdownLock.unlock()

        flushIntervalTimer?.cancel()
        flushIntervalTimer = nil

        flush()
        writeQueue.sync { }

        waitForFinalUpload()

        for cancellable in cancellables {
            cancellable.cancel()
        }
        cancellables.removeAll()
    }

    deinit {
        flushIntervalTimer?.cancel()
    }

    private func waitForFinalUpload() {
        let shutdownComplete = DispatchSemaphore(value: 0)
        Task {
            await self.upload(sealCurrentBatch: true)
            shutdownComplete.signal()
        }
        if shutdownComplete.wait(timeout: .now() + shutdownTimeout) == .timedOut {
            debugLogger?.logMessage(
                message: "Timed out waiting for final event upload; pending events remain stored for retry",
                isWarning: true
            )
        }
    }

    private func startFlushIntervalTimer(_ interval: TimeInterval) {
        let timer = DispatchSource.makeTimerSource(queue: writeQueue)
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { [weak self] in
            self?.flush()
        }
        timer.resume()
        flushIntervalTimer = timer
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
