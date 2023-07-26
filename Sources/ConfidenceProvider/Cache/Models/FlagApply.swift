import Foundation

struct FlagApply: Codable {
    let name: String
    var applyEvent: ApplyEvent

    init(name: String, applyTime: Date) {
        self.name = name
        self.applyEvent = ApplyEvent(applyTime: applyTime)
    }
}
