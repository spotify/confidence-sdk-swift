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

    // Storage Keys
    private static var userDefaultVersionNameKey = "CONFIDENCE_VERSION_NAME_KEY"
    private static var userDefaultBuildNameKey = "CONFIDENCE_BUILD_NUMBER_KEY"
    // Context Keys
    private static var versionNameContextKey = "app_version"
    private static var buildNumberContextKey = "app_build"
    // Event Names
    private static let appLaunchedEventName = "app-launched"
    private static let appInstalledEventName = "app-installed"
    private static let appUpdatedEventName = "app-updated"


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
            Self.versionNameContextKey: .init(string: currentVersion),
            Self.buildNumberContextKey: .init(string: currentBuild)
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

    private func track(eventName: String, shouldFlush: Bool) {
        let previousBuild: String? = UserDefaults.standard.string(forKey: Self.userDefaultBuildNameKey)
        let previousVersion: String? = UserDefaults.standard.string(forKey: Self.userDefaultVersionNameKey)

        let currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let currentBuild: String = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""

        if eventName == Self.appLaunchedEventName {
            if previousBuild == nil && previousVersion == nil {
                events.send(Event(
                    name: ConfidenceAppLifecycleProducer.appInstalledEventName,
                    data: [:],
                    shouldFlush: shouldFlush)
                )
            } else if previousBuild != currentBuild || previousVersion != currentVersion {
                events.send(Event(
                    name: ConfidenceAppLifecycleProducer.appUpdatedEventName,
                    data: [:],
                    shouldFlush: shouldFlush)
                )
            }
        }
        events.send(Event(name: eventName, data: [:], shouldFlush: shouldFlush))

        UserDefaults.standard.setValue(currentVersion, forKey: Self.userDefaultVersionNameKey)
        UserDefaults.standard.setValue(currentBuild, forKey: Self.userDefaultBuildNameKey)
    }

    private func withLock(callback: @escaping () -> Void) {
        queue.sync {
            callback()
        }
    }

    @objc func notificationResponse(notification: NSNotification) {
        switch notification.name {
        case UIApplication.didBecomeActiveNotification:
            track(eventName: Self.appLaunchedEventName, shouldFlush: true)
        default:
            break
        }
    }
}
#endif
