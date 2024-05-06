import Foundation
import UIKit
import Combine

public class ConfidenceScreenTracker: ConfidenceEventProducer {
    private var events = PassthroughSubject<Event, Never>()
    public func produceEvents() -> AnyPublisher<Event, Never> {
        events.eraseToAnyPublisher()
    }

    static let notificationName = Notification.Name(rawValue: "ConfidenceScreenTracker")
    static let screenName = "screen_name"
    static let messageKey = "message_json"
    static let controllerKey = "controller"

    public init() {
        swizzle(
            forClass: UIViewController.self,
            original: #selector(UIViewController.viewDidAppear(_:)),
            new: #selector(UIViewController.confidence__viewDidAppear)
        )

        swizzle(
            forClass: UIViewController.self,
            original: #selector(UIViewController.viewDidDisappear(_:)),
            new: #selector(UIViewController.confidence__viewDidDisappear)
        )

        NotificationCenter.default.addObserver(
            forName: Self.notificationName,
            object: nil,
            queue: OperationQueue.main) { [weak self] notification in
                let name = notification.userInfo?[Self.screenName] as? String
                let messageJson = (notification.userInfo?[Self.messageKey] as? String)?.data(using: .utf8)
                var message: ConfidenceStruct = [:]
                if let data = messageJson {
                    let decoder = JSONDecoder()
                    do {
                        message = try decoder.decode(ConfidenceStruct.self, from: data)
                    } catch {
                    }
                }

                guard let self = self else {
                    return
                }
                if let name = name {
                    self.events.send(Event(name: name, message: message))
                }
        }
    }

    private func swizzle(forClass: AnyClass, original: Selector, new: Selector) {
        guard let originalMethod = class_getInstanceMethod(forClass, original) else { return }
        guard let swizzledMethod = class_getInstanceMethod(forClass, new) else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}

public protocol TrackableComponent {
    func trackName() -> String
}

public protocol TrackableComponentWithMessage: TrackableComponent {
    func trackMessage() -> ConfidenceStruct
}

extension UIViewController {
    private func sendNotification(event: String) {
        var className = String(describing: type(of: self))
            .replacingOccurrences(of: "ViewController", with: "")
        var message: [String: String] = [ConfidenceScreenTracker.screenName: className]

        if let trackable = self as? TrackableComponent {
            className = trackable.trackName()
            if let trackableWithMessage = self as? TrackableComponentWithMessage {
                let encoder = JSONEncoder()
                do {
                    let data = try encoder.encode(trackableWithMessage.trackMessage())
                    let messageString = String(data: data, encoding: .utf8)
                    if let json = messageString {
                        message.updateValue(json, forKey: ConfidenceScreenTracker.messageKey)
                    }
                } catch {
                }
            }
        }

        NotificationCenter.default.post(
            name: ConfidenceScreenTracker.notificationName,
            object: self,
            userInfo: message
        )
    }
    @objc internal func confidence__viewDidAppear(animated: Bool) {
    }

    @objc internal func confidence__viewDidDisappear(animated: Bool) {
    }
}
