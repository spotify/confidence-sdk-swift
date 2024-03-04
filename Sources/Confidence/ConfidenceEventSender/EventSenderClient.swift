import Foundation

typealias EventHTTPResponse = HttpClientResponse<EventResponse>
typealias EventResult = Result<EventHTTPResponse, Error>

public class EventSenderClient: EventSender {
    private var httpClient = NetworkClient(region: .eventsEu)
    private var secret: String

    init(
        secret: String
    ) {
        self.secret = secret
    }

    public func send<T: Codable>(eventName: String, message: T) {
        Task {
            if #available(iOS 15.0, *) {
                let request = EventRequest(
                    clientSecret: secret,
                    events: [Event(
                        eventDefinition: "eventDefinitions/\(eventName)",
                        payload: message,
                        eventTime: Date.now.ISO8601Format())],
                    sendTime: Date.now.ISO8601Format())
                let _: EventResult = try await self.httpClient.post(path: ":publish", data: request)
            } else {
                // Fallback on earlier versions
            }
        }
    }
}


struct EventRequest<T: Codable>: Codable {
    var clientSecret: String
    var events: [Event<T>]
    var sendTime: String
}

struct Event<T: Codable>: Codable {
    var eventDefinition: String
    var payload: T
    var eventTime: String
}

struct EventResponse: Decodable { }
