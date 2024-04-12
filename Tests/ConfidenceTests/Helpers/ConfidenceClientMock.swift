import Foundation

@testable import Confidence

class ConfidenceClientMock: ConfidenceClient {
    func upload(batch: [ConfidenceEvent]) async throws -> Bool {
        return true
    }
}
