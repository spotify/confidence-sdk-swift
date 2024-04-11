import Foundation

public protocol ConfidenceClient {
    func send(definition: String, payload: ConfidenceStruct) async throws
}
