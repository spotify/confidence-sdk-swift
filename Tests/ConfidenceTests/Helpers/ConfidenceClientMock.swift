import Foundation

@testable import Confidence

class ConfidenceClientMock: ConfidenceClient {
    func send(definition: String, payload: ConfidenceStruct) async throws {
        // NO-OP
    }
}
