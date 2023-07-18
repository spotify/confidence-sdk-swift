import Foundation

struct FlagApply: Codable {
    let name: String
    var applyTime: Date

    init(name: String, applyTime: Date) {
        self.name = name
        self.applyTime = applyTime
    }
}
