import Foundation

struct FlagApply: Codable {
    let name: String
    let applyTime: Date
    var status: ApplyEventStatus

    init(name: String, applyTime: Date, status: ApplyEventStatus = .created) {
        self.name = name
        self.applyTime = applyTime
        self.status = status
    }
}
