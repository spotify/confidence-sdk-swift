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

    @objc func notificationResponse(notification: NSNotification) {
        switch notification.name {
        case UIApplication.didEnterBackgroundNotification:
            events.send(Event(name: "enter-background"))
        case UIApplication.willEnterForegroundNotification:
            events.send(Event(name: "enter-foreground"))
        case UIApplication.didFinishLaunchingNotification:
            events.send(Event(name: "app-launched"))
        case UIApplication.didBecomeActiveNotification:
            events.send(Event(name: "app-active"))
        case UIApplication.willResignActiveNotification:
            events.send(Event(name: "resign-active"))
        case UIApplication.didReceiveMemoryWarningNotification:
            events.send(Event(name: "memory-warning"))
        case UIApplication.significantTimeChangeNotification:
            events.send(Event(name: "significant-time-change"))
        case UIApplication.backgroundRefreshStatusDidChangeNotification:
            events.send(Event(name: "bg-refresh-status-changed"))
        default:
            break
        }
    }
}
#endif
