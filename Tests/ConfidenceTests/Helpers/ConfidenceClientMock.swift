import Foundation

@testable import Confidence

class ConfidenceClientMock: ConfidenceClient {
    func upload(batch: [ConfidenceClientEvent]) async throws {
        // NO-OP
    }
}
