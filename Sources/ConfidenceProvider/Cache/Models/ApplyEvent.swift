import Foundation

struct ApplyEvent: Codable {
    let applyTime: Date
    var status: ApplyEventStatus

    init(applyTime: Date, status: ApplyEventStatus = .created) {
        self.applyTime = applyTime
        self.status = status
    }
}
