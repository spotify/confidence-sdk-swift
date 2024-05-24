import Foundation
@testable import Confidence

class EventSenderEngineMock: EventSenderEngine {
    func emit(eventName: String, message: ConfidenceStruct, context: ConfidenceStruct) {
        // NO-OP
    }

    func shutdown() {
        // NO-OP
    }

    func flush() {
        // NO-OP
    }
}
