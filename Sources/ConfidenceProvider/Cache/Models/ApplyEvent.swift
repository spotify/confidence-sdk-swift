import Foundation

struct ApplyEvent: Codable {
    let applyTime: Date
    var sent: Bool

    init(applyTime: Date, sent: Bool = false) {
        self.applyTime = applyTime
        self.sent = sent
    }
}
