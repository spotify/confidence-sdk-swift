#if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
import Foundation
import UIKit
import Combine

public struct Event {
    let name: String
    let message: ConfidenceStruct

    public init(name: String, message: ConfidenceStruct = [:]) {
        self.name = name
        self.message = message
    }
}

public class ConfidenceAppLifecycleMonitor: ConfidenceEventProducer, ObservableObject {
    private var events = CurrentValueSubject<Event?, Never>(nil)
    public func produceEvents() -> AnyPublisher<Event, Never> {
        events.compactMap { event in event }.eraseToAnyPublisher()
    }
    private var appNotifications: [NSNotification.Name] = [
        UIApplication.didEnterBackgroundNotification,
        UIApplication.willEnterForegroundNotification,
        UIApplication.didFinishLaunchingNotification,
        UIApplication.didBecomeActiveNotification,
        UIApplication.willResignActiveNotification,
        UIApplication.didReceiveMemoryWarningNotification,
        UIApplication.willTerminateNotification,
        UIApplication.significantTimeChangeNotification,
        UIApplication.backgroundRefreshStatusDidChangeNotification
    ]

    static var versionNameKey = "CONFIDENCE_VERSION_NAME_KEY"
    static var buildNameKey = "CONFIDENCE_VERSIONN_KEY"
    private var isLaunched = false

    public init() {
        for notification in appNotifications {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(notificationResponse),
                name: notification,
                object: nil
            )
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func track(eventName: String, sourceApp: String = "", url: String = "") {
        let previousBuild: String? = UserDefaults.standard.string(forKey: Self.buildNameKey)
        let previousVersion: String? = UserDefaults.standard.string(forKey: Self.versionNameKey)

        let currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let currentBuild: String = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""

        var message: ConfidenceStruct = [
            "version": .init(string: currentVersion),
            "build": .init(string: currentBuild)
        ]

        // handle referreres
        if !sourceApp.isEmpty {
            message.updateValue(ConfidenceValue.init(string: sourceApp), forKey: "source-app")
        }
        if !url.isEmpty {
            message.updateValue(ConfidenceValue.init(string: url), forKey: "source-url")
        }

        if eventName == "app-launched" && !isLaunched {
            isLaunched = true
            if previousBuild != currentBuild || previousVersion != currentVersion {
                events.send(Event(name: "app-updated", message: message))
                return
            } else {
                events.send(Event(name: "app-installed", message: message))
                return
            }
        }

        events.send(Event(name: eventName, message: message))

        UserDefaults.standard.setValue(currentVersion, forKey: Self.versionNameKey)
        UserDefaults.standard.setValue(currentBuild, forKey: Self.buildNameKey)
    }

    @objc func notificationResponse(notification: NSNotification) {
        switch notification.name {
        case UIApplication.didEnterBackgroundNotification:
            track(eventName: "enter-background")
        case UIApplication.willEnterForegroundNotification:
            track(eventName: "enter-foreground")
        case UIApplication.didFinishLaunchingNotification:
            let options = notification.userInfo as? [UIApplication.LaunchOptionsKey: Any] ?? nil
            let sourceApp: String = options?[UIApplication.LaunchOptionsKey.sourceApplication] as? String ?? ""
            let url: String = options?[UIApplication.LaunchOptionsKey.url] as? String ?? ""
            track(eventName: "app-launch", sourceApp: sourceApp, url: url)
        case UIApplication.didBecomeActiveNotification:
            track(eventName: "app-active")
        case UIApplication.willResignActiveNotification:
            track(eventName: "resign-active")
        case UIApplication.didReceiveMemoryWarningNotification:
            track(eventName: "memory-warning")
        case UIApplication.significantTimeChangeNotification:
            track(eventName: "significant-time-change")
        case UIApplication.backgroundRefreshStatusDidChangeNotification:
            track(eventName: "bg-refresh-status-changed")
        default:
            break
        }
    }
}
#endif
