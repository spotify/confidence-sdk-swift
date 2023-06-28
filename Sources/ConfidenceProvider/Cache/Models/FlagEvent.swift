import Foundation

struct FlagEvent: Codable {
    let name: String
    var applyEvents: [ApplyEvent]

    init(name: String, applyTime: Date) {
        self.name = name
        self.applyEvents = [ApplyEvent(id: UUID(), applyTime: applyTime)]
    }

    init(name: String, applyTime: Date, uuid: UUID) {
        self.name = name
        self.applyEvents = [ApplyEvent(id: uuid, applyTime: applyTime)]
    }
}
