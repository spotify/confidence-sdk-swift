import Foundation

struct ResolveEvent: Codable {
    let resolveToken: String
    var events: [FlagEvent]

    var isEmpty: Bool {
        resolveToken.isEmpty
    }

    init(resolveToken: String, flagName: String, applyTime: Date) {
        self.resolveToken = resolveToken
        self.events = [FlagEvent(name: flagName, applyTime: applyTime)]
    }

    init(resolveToken: String, events: [FlagEvent]) {
        self.resolveToken = resolveToken
        self.events = events
    }
}
