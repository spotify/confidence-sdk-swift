import Foundation

@testable import Confidence

class ConfidenceClientMock: ConfidenceClient {
    func upload(events: [NetworkEvent]) async throws -> Bool {
        return true
    }
}
