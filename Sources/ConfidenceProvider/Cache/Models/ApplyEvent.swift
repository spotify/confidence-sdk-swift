import Foundation

struct ApplyEvent: Codable, Identifiable {
    let id: UUID
    let applyTime: Date
}
