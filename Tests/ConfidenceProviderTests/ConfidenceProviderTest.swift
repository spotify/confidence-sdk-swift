import Foundation
import ConfidenceProvider
import Combine
import OpenFeature
import XCTest

@testable import Confidence

class ConfidenceProviderTest: XCTestCase {
    func testErrorFetchOnInit() async throws {
        let readyExpectation = XCTestExpectation(description: "Ready")
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

        let cancellable = OpenFeatureAPI.shared.observe().sink { event in
            if event == .ready {
                readyExpectation.fulfill()
            } else {
                print(event.debugDescription)
            }
        }

        let provider = ConfidenceFeatureProvider(confidence: confidence, initializationStrategy: .activateAndFetchAsync)
        OpenFeatureAPI.shared.setProvider(provider: provider)

        await fulfillment(of: [readyExpectation], timeout: 5.0)
        cancellable.cancel()
    }

    func testErrorStorageOnInit() async throws {
        let errorExpectation = XCTestExpectation(description: "Error")
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

        let cancellable = OpenFeatureAPI.shared.observe().sink { event in
            if let event = event {
                if case .error = event {
                    errorExpectation.fulfill()
                } else {
                    // no-op
                }
            }
        }

        let provider = ConfidenceFeatureProvider(confidence: confidence, initializationStrategy: .activateAndFetchAsync)
        OpenFeatureAPI.shared.setProvider(provider: provider)

        await fulfillment(of: [errorExpectation], timeout: 5.0)
        cancellable.cancel()
    }

    func testProviderThrowsOpenFeatureErrors() async throws {
        let context = MutableContext(targetingKey: "t")
        let readyExpectation = XCTestExpectation(description: "Ready")
        let storage = StorageMock()
        class FakeClient: ConfidenceResolveClient {
            var resolvedValues: [ResolvedValue] = [
                ResolvedValue(
                variant: "variant1",
                value: .init(structure: ["int": .init(integer: 42)]),
                flag: "flagName",
                resolveReason: .match,
                shouldApply: true)
            ]
            func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
                return .init(resolvedValues: resolvedValues, resolveToken: "token")
            }
        }

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "t")])
            .withFlagResolverClient(flagResolver: FakeClient())
            .withStorage(storage: storage)
            .build()

        let provider = ConfidenceFeatureProvider(confidence: confidence, initializationStrategy: .fetchAndActivate)
        OpenFeatureAPI.shared.setProvider(provider: provider)
        let cancellable = OpenFeatureAPI.shared.observe().sink { event in
            if event == .ready {
                readyExpectation.fulfill()
            } else {
                print(event.debugDescription)
            }
        }
        await fulfillment(of: [readyExpectation], timeout: 1.0)
        cancellable.cancel()
        let evaluation = try provider.getIntegerEvaluation(key: "flagName.int", defaultValue: -1, context: context)
        XCTAssertEqual(evaluation.value, 42)

        XCTAssertThrowsError(
            try provider.getIntegerEvaluation(
                key: "flagNotFound.something",
                defaultValue: -1,
                context: context))
        { error in
            if let specificError = error as? OpenFeatureError {
                XCTAssertEqual(specificError.errorCode(), ErrorCode.flagNotFound)
            } else {
                XCTFail("expected a flag not found error")
            }
        }
    }
}

private class StorageMock: Storage {
    var data = ""
    var saveExpectation: XCTestExpectation?
    private let storageQueue = DispatchQueue(label: "com.confidence.storagemock")

    convenience init(data: Encodable) throws {
        self.init()
        try self.save(data: data)
    }

    func save(data: Encodable) throws {
        try storageQueue.sync {
            let dataB = try JSONEncoder().encode(data)
            self.data = try XCTUnwrap(String(data: dataB, encoding: .utf8))

            saveExpectation?.fulfill()
        }
    }

    func load<T>(defaultValue: T) throws -> T where T: Decodable {
        try storageQueue.sync {
            if data.isEmpty {
                return defaultValue
            }
            return try JSONDecoder().decode(T.self, from: try XCTUnwrap(data.data(using: .utf8)))
        }
    }

    func clear() throws {
        storageQueue.sync {
            data = ""
        }
    }

    func isEmpty() -> Bool {
        storageQueue.sync {
            return data.isEmpty
        }
    }
}
