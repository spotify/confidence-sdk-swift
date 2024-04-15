import Foundation
@testable import Confidence

class EventSenderEngineMock: EventSenderEngine {
    func emit(definition: String, payload: ConfidenceStruct, context: ConfidenceStruct) {
        // NO-OP
    }

    func shutdown() {
        // NO-OP
    }
}
