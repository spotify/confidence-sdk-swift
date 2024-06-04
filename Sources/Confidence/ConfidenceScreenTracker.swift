#if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
import Foundation
import UIKit
import Combine

public class ConfidenceScreenTracker: ConfidenceEventProducer {
    private var events = BufferedPassthrough<Event>()
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
                var data: ConfidenceStruct = [:]
                if let messageData = messageJson {
                    let decoder = JSONDecoder()
                    do {
                        data = try decoder.decode(ConfidenceStruct.self, from: messageData)
                    } catch {
                    }
                }

                guard let self = self else {
                    return
                }
                if let name = name {
                    self.events.send(Event(name: name, data: data))
                }
        }
    }

    public func produceEvents() -> AnyPublisher<Event, Never> {
        events.publisher()
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
                    let messageString = String(decoding: data, as: UTF8.self)
                    message.updateValue(messageString, forKey: ConfidenceScreenTracker.messageKey)
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
#endif
