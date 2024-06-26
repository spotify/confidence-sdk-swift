import Foundation

@testable import Confidence

class ConfidenceClientMock: ConfidenceEventsClient {
    func upload(events: [NetworkEvent]) async throws -> Bool {
        return true
    }
}
