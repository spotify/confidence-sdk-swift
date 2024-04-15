import Foundation

struct EventBatchRequest: Encodable {
    let clientSecret: String
    let sendTime: Date
    let events: [Event]
}
