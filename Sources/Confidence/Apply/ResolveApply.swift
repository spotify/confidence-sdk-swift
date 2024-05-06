import Foundation

struct ResolveApply: Codable {
    let resolveToken: String
    var events: [FlagApply]

    var isEmpty: Bool {
        resolveToken.isEmpty || events.isEmpty
    }

    var isSent: Bool {
        events.allSatisfy { $0.status == .sent }
    }

    init(resolveToken: String, flagName: String, applyTime: Date) {
        self.resolveToken = resolveToken
        self.events = [FlagApply(name: flagName, applyTime: applyTime)]
    }

    init(resolveToken: String, events: [FlagApply]) {
        self.resolveToken = resolveToken
        self.events = events
    }
}
