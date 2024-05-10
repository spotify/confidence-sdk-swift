#if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
import Foundation
import UIKit
import Combine

public class ConfidenceAppLifecycleProducer: ConfidenceEventProducer, ConfidenceContextProducer, ObservableObject {
    public var currentProducedContext: CurrentValueSubject<ConfidenceStruct, Never> = CurrentValueSubject([:])
    private var events: BufferedPassthrough<Event> = BufferedPassthrough()
    private let queue = DispatchQueue(label: "com.confidence.lifecycle_producer")
    private var appNotifications: [NSNotification.Name] = [
        UIApplication.didEnterBackgroundNotification,
        UIApplication.willEnterForegroundNotification,
        UIApplication.didBecomeActiveNotification
    ]

    private static var versionNameKey = "CONFIDENCE_VERSION_NAME_KEY"
    private static var buildNameKey = "CONFIDENCE_VERSIONN_KEY"
    private let appLaunchedEventName = "app-launched"

    public init() {
        for notification in appNotifications {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(notificationResponse),
                name: notification,
                object: nil
            )
        }

        let currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let currentBuild: String = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        let context: ConfidenceStruct = [
            "version": .init(string: currentVersion),
            "build": .init(string: currentBuild)
        ]

        self.currentProducedContext.send(context)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public func produceEvents() -> AnyPublisher<Event, Never> {
        events.publisher()
    }

    public func produceContexts() -> AnyPublisher<ConfidenceStruct, Never> {
        currentProducedContext
            .filter { context in !context.isEmpty }
            .eraseToAnyPublisher()
    }

    private func track(eventName: String) {
        let previousBuild: String? = UserDefaults.standard.string(forKey: Self.buildNameKey)
        let previousVersion: String? = UserDefaults.standard.string(forKey: Self.versionNameKey)

        let currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let currentBuild: String = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""

        let message: ConfidenceStruct = [
            "version": .init(string: currentVersion),
            "build": .init(string: currentBuild)
        ]

        if eventName == self.appLaunchedEventName {
            if previousBuild == nil && previousVersion == nil {
                events.send(Event(name: "app-installed", message: message))
            } else if previousBuild != currentBuild || previousVersion != currentVersion {
                events.send(Event(name: "app-updated", message: message))
            }
        }
        events.send(Event(name: eventName, message: message))

        UserDefaults.standard.setValue(currentVersion, forKey: Self.versionNameKey)
        UserDefaults.standard.setValue(currentBuild, forKey: Self.buildNameKey)
    }

    private func updateContext(isForeground: Bool) {
        withLock { [weak self] in
            guard let self = self else {
                return
            }
            var context = self.currentProducedContext.value
            context.updateValue(.init(boolean: isForeground), forKey: "is_foreground")
            self.currentProducedContext.send(context)
        }
    }

    private func withLock(callback: @escaping () -> Void) {
        queue.sync {
            callback()
        }
    }

    @objc func notificationResponse(notification: NSNotification) {
        switch notification.name {
        case UIApplication.didEnterBackgroundNotification:
            updateContext(isForeground: false)
        case UIApplication.willEnterForegroundNotification:
            updateContext(isForeground: true)
        case UIApplication.didBecomeActiveNotification:
            track(eventName: appLaunchedEventName)
        default:
            break
        }
    }
}
#endif
