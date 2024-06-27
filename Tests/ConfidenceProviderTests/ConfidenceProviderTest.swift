import Foundation
import ConfidenceProvider
import Combine
import OpenFeature
import XCTest

@testable import Confidence

class ConfidenceProviderTest: XCTestCase {
    private var readyExpectation = XCTestExpectation(description: "Ready")
    private var errorExpectation = XCTestExpectation(description: "Error")

    func testErrorFetchOnInit() async throws {
        class FakeClient: ConfidenceResolveClient {
            func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
                throw ConfidenceError.internalError(message: "test")
            }
        }

        let client = FakeClient()
        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user1")])
            .withFlagResolverClient(flagResolver: client)
            .build()

        let provider = ConfidenceFeatureProvider(confidence: confidence, initializationStrategy: .activateAndFetchAsync)
        OpenFeatureAPI.shared.setProvider(provider: provider)

        let cancellable = OpenFeatureAPI.shared.observe().sink { event in
            if event == .ready {
                self.readyExpectation.fulfill()
            } else {
                print(event)
            }
        }
        await fulfillment(of: [readyExpectation], timeout: 5.0)
        cancellable.cancel()
    }

    func testErrorStorageOnInit() async throws {
        class FakeStorage: Storage {
            func save(data: Encodable) throws {
                // no-op
            }

            func load<T>(defaultValue: T) throws -> T where T: Decodable {
                throw ConfidenceError.internalError(message: "test")
            }

            func clear() throws {
                // no-op
            }

            func isEmpty() -> Bool {
                return false
            }
        }

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user1")])
            .withStorage(storage: FakeStorage())
            .build()

        let provider = ConfidenceFeatureProvider(confidence: confidence, initializationStrategy: .activateAndFetchAsync)
        OpenFeatureAPI.shared.setProvider(provider: provider)

        let cancellable = OpenFeatureAPI.shared.observe().sink { event in
            if event == .error {
                self.errorExpectation.fulfill()
            } else {
                print(event)
            }
        }
        await fulfillment(of: [errorExpectation], timeout: 5.0)
        cancellable.cancel()
    }
}
