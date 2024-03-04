import Foundation

public protocol EventSender {
    func send<P: Codable>(eventName: String, message: P)
}
