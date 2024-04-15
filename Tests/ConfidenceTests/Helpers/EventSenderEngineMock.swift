import Foundation
@testable import Confidence

class EventSenderEngineMock: EventSenderEngine {
    func send(name: String, message: ConfidenceStruct) {
        // NO-OP
    }

    func shutdown() {
        // NO-OP
    }
}
