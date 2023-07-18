import Foundation

struct ApplyEvent: Codable {
    let applyTime: Date

    init(applyTime: Date) {
        self.applyTime = applyTime
    }
}
