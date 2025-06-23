// swiftlint:disable file_length
import Foundation
import ConfidenceProvider
import Combine
import OpenFeature
import XCTest

@testable import Confidence

// swiftlint:disable:next type_body_length
class ConfidenceProviderTest: XCTestCase {
    // MARK: - Helper Functions

    private func createFakeClient(
        resolvedValues: [ResolvedValue],
        shouldThrow: Bool = false,
        error: Error = ConfidenceError.internalError(message: "test")
    ) -> ConfidenceResolveClient {
        class FakeClient: ConfidenceResolveClient {
            let resolvedValues: [ResolvedValue]
            let shouldThrow: Bool
            let error: Error

            init(resolvedValues: [ResolvedValue], shouldThrow: Bool, error: Error) {
                self.resolvedValues = resolvedValues
                self.shouldThrow = shouldThrow
                self.error = error
            }

            func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
                if shouldThrow {
                    throw error
                }
                return .init(resolvedValues: resolvedValues, resolveToken: "token")
            }
        }

        return FakeClient(resolvedValues: resolvedValues, shouldThrow: shouldThrow, error: error)
    }

    private func createFakeStorage(shouldThrowOnLoad: Bool = false) -> Storage {
        class FakeStorage: Storage {
            let shouldThrowOnLoad: Bool

            init(shouldThrowOnLoad: Bool) {
                self.shouldThrowOnLoad = shouldThrowOnLoad
            }

            func save(data: Encodable) throws {
                // no-op
            }

            func load<T>(defaultValue: T) throws -> T where T: Decodable {
                if shouldThrowOnLoad {
                    throw ConfidenceError.internalError(message: "test")
                }
                return defaultValue
            }

            func clear() throws {
                // no-op
            }

            func isEmpty() -> Bool {
                return false
            }
        }

        return FakeStorage(shouldThrowOnLoad: shouldThrowOnLoad)
    }

    private func setupProviderAndWaitForReady(
        confidence: Confidence,
        initializationStrategy: InitializationStrategy = .fetchAndActivate,
        timeout: TimeInterval = 1.0
    ) async -> AnyCancellable {
        let readyExpectation = XCTestExpectation(description: "Ready")

        let provider = ConfidenceFeatureProvider(confidence: confidence, initializationStrategy: initializationStrategy)
        OpenFeatureAPI.shared.setProvider(provider: provider)

        let cancellable = OpenFeatureAPI.shared.observe().sink { event in
            if event == .ready {
                readyExpectation.fulfill()
            } else {
                print(event.debugDescription)
            }
        }

        await fulfillment(of: [readyExpectation], timeout: timeout)
        return cancellable
    }

    private func setupProviderAndWaitForError(
        confidence: Confidence,
        initializationStrategy: InitializationStrategy = .activateAndFetchAsync,
        timeout: TimeInterval = 5.0
    ) async -> AnyCancellable {
        let errorExpectation = XCTestExpectation(description: "Error")

        let provider = ConfidenceFeatureProvider(confidence: confidence, initializationStrategy: initializationStrategy)
        OpenFeatureAPI.shared.setProvider(provider: provider)

        let cancellable = OpenFeatureAPI.shared.observe().sink { event in
            if let event = event {
                if case .error = event {
                    errorExpectation.fulfill()
                }
            }
        }

        await fulfillment(of: [errorExpectation], timeout: timeout)
        return cancellable
    }

    private func createResolvedValue(
        variant: String = "control",
        structure: [String: ConfidenceValue],
        flag: String = "flag",
        resolveReason: ResolveReason = .match,
        shouldApply: Bool = true
    ) -> ResolvedValue {
        return ResolvedValue(
            variant: variant,
            value: .init(structure: structure),
            flag: flag,
            resolveReason: resolveReason,
            shouldApply: shouldApply
        )
    }

    // MARK: - Tests

    func testErrorFetchOnInit() async throws {
        let client = createFakeClient(resolvedValues: [], shouldThrow: true)
        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user1")])
            .withFlagResolverClient(flagResolver: client)
            .build()

        let cancellable = await setupProviderAndWaitForReady(
            confidence: confidence,
            initializationStrategy: .activateAndFetchAsync,
            timeout: 5.0
        )
        cancellable.cancel()
    }

    func testErrorStorageOnInit() async throws {
        let storage = createFakeStorage(shouldThrowOnLoad: true)
        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user1")])
            .withStorage(storage: storage)
            .build()

        let cancellable = await setupProviderAndWaitForError(
            confidence: confidence,
            initializationStrategy: .activateAndFetchAsync,
            timeout: 5.0
        )
        cancellable.cancel()
    }

    func testProviderThrowsOpenFeatureErrors() async throws {
        let context = MutableContext(targetingKey: "t")
        let storage = StorageMock()

        let resolvedValue = createResolvedValue(
            variant: "variant1",
            structure: ["int": .init(integer: 42)],
            flag: "flagName"
        )
        let client = createFakeClient(resolvedValues: [resolvedValue])

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "t")])
            .withFlagResolverClient(flagResolver: client)
            .withStorage(storage: storage)
            .build()

        let cancellable = await setupProviderAndWaitForReady(confidence: confidence)
        cancellable.cancel()

        let provider = ConfidenceFeatureProvider(confidence: confidence, initializationStrategy: .fetchAndActivate)
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

    func testProviderThrowsParseErrorOnObjectEval() async throws {
        let context = MutableContext(targetingKey: "t")
        let storage = StorageMock()

        let resolvedValue = createResolvedValue(
            variant: "variant1",
            structure: ["int": .init(integer: 42)],
            flag: "flagName"
        )
        let client = createFakeClient(resolvedValues: [resolvedValue])

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "t")])
            .withFlagResolverClient(flagResolver: client)
            .withStorage(storage: storage)
            .build()

        let cancellable = await setupProviderAndWaitForReady(confidence: confidence)
        cancellable.cancel()

        let provider = ConfidenceFeatureProvider(confidence: confidence, initializationStrategy: .fetchAndActivate)
        XCTAssertThrowsError(
            try provider.getIntegerEvaluation(key: "flagName", defaultValue: -1, context: context))
        { error in
            if let specificError = error as? OpenFeatureError {
                XCTAssertEqual(specificError.errorCode(), ErrorCode.typeMismatch)
                XCTAssertEqual(specificError.description, "Type mismatch")
            } else {
                XCTFail("expected a flag not found error")
            }
        }
    }

    func testProviderObjectEval() async throws {
        let context = MutableContext(targetingKey: "t")
        let storage = StorageMock()

        let resolvedValue = createResolvedValue(
            variant: "variant1",
            structure: ["int": .init(integer: 42)],
            flag: "flagName"
        )
        let client = createFakeClient(resolvedValues: [resolvedValue])

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "t")])
            .withFlagResolverClient(flagResolver: client)
            .withStorage(storage: storage)
            .build()

        let cancellable = await setupProviderAndWaitForReady(confidence: confidence)
        cancellable.cancel()

        let provider = ConfidenceFeatureProvider(confidence: confidence, initializationStrategy: .fetchAndActivate)
        let evaluation = try provider.getObjectEvaluation(
            key: "flagName",
            defaultValue: Value.structure(["int": .integer(3)]),
            context: context)

        guard case let .structure(resultMap) = evaluation.value else {
            XCTFail("Expected structure value")
            return
        }

        XCTAssertEqual(resultMap["int"], .integer(42))
        XCTAssertEqual(evaluation.variant, "variant1")
        XCTAssertEqual(evaluation.reason, "targetingMatch")
    }

    func testProviderResolveStruct() async throws {
        let context = MutableContext(targetingKey: "user2")
        let storage = StorageMock()

        let resolvedValue = createResolvedValue(
            structure: ["size": .init(integer: 3)]
        )
        let client = createFakeClient(resolvedValues: [resolvedValue])

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withStorage(storage: storage)
            .build()

        let cancellable = await setupProviderAndWaitForReady(confidence: confidence)
        cancellable.cancel()

        let provider = ConfidenceFeatureProvider(confidence: confidence, initializationStrategy: .fetchAndActivate)
        let evaluation = try provider.getObjectEvaluation(
            key: "flag",
            defaultValue: Value.structure(["size": .integer(0)]),
            context: context)

        guard case let .structure(resultMap) = evaluation.value else {
            XCTFail("Expected structure value")
            return
        }

        XCTAssertEqual(resultMap["size"], .integer(3))
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(evaluation.reason, "targetingMatch")
        XCTAssertNil(evaluation.errorCode)
        XCTAssertNil(evaluation.errorMessage)
    }

    func testProviderResolveInnerStruct() async throws {
        let context = MutableContext(targetingKey: "user2")
        let storage = StorageMock()

        let resolvedValue = createResolvedValue(
            structure: ["size": .init(structure: ["border": .init(integer: 420)])]
        )
        let client = createFakeClient(resolvedValues: [resolvedValue])

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withStorage(storage: storage)
            .build()

        let cancellable = await setupProviderAndWaitForReady(confidence: confidence)
        cancellable.cancel()

        let provider = ConfidenceFeatureProvider(confidence: confidence, initializationStrategy: .fetchAndActivate)
        let evaluation = try provider.getObjectEvaluation(
            key: "flag",
            defaultValue: Value.structure(["size": .structure(["border": .integer(0)])]),
            context: context)

        guard case let .structure(resultMap) = evaluation.value else {
            XCTFail("Expected structure value")
            return
        }

        guard case let .structure(sizeMap) = resultMap["size"] else {
            XCTFail("Expected nested structure value")
            return
        }

        XCTAssertEqual(sizeMap["border"], .integer(420))
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(evaluation.reason, "targetingMatch")
    }

    func testProviderResolveStructSchemaMismatch() async throws {
        let context = MutableContext(targetingKey: "user2")
        let storage = StorageMock()

        let resolvedValue = createResolvedValue(
            structure: ["size": .init(integer: 44)]
        )
        let client = createFakeClient(resolvedValues: [resolvedValue])

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withStorage(storage: storage)
            .build()

        let cancellable = await setupProviderAndWaitForReady(confidence: confidence)
        cancellable.cancel()

        let provider = ConfidenceFeatureProvider(confidence: confidence, initializationStrategy: .fetchAndActivate)
        XCTAssertThrowsError(
            try provider.getObjectEvaluation(
                key: "flag.size",
                defaultValue: Value.structure(["test": .string("wrong_type")]),
                context: context)
        ) { error in
            if let specificError = error as? OpenFeatureError {
                XCTAssertEqual(specificError.errorCode(), ErrorCode.typeMismatch)
            } else {
                XCTFail("Expected a type mismatch error")
            }
        }
    }

    func testProviderResolveStructSchemaExtraValues() async throws {
        let context = MutableContext(targetingKey: "user2")
        let storage = StorageMock()

        let resolvedValue = createResolvedValue(
            structure: [
                "width": .init(integer: 200),
                "height": .init(integer: 400)
            ]
        )
        let client = createFakeClient(resolvedValues: [resolvedValue])

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withStorage(storage: storage)
            .build()

        let cancellable = await setupProviderAndWaitForReady(confidence: confidence)
        cancellable.cancel()

        let provider = ConfidenceFeatureProvider(confidence: confidence, initializationStrategy: .fetchAndActivate)
        let evaluation = try provider.getObjectEvaluation(
            key: "flag",
            defaultValue: Value.structure(["width": .integer(100)]),
            context: context)

        guard case let .structure(resultMap) = evaluation.value else {
            XCTFail("Expected structure value")
            return
        }

        XCTAssertEqual(resultMap["width"], .integer(200))
        XCTAssertNil(resultMap["height"])
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(evaluation.reason, "targetingMatch")
    }

    func testProviderResolveStructHeterogenous() async throws {
        let context = MutableContext(targetingKey: "user2")
        let storage = StorageMock()

        let resolvedValue = createResolvedValue(
            structure: [
                "width": .init(integer: 200),
                "color": .init(string: "yellow")
            ]
        )
        let client = createFakeClient(resolvedValues: [resolvedValue])

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withStorage(storage: storage)
            .build()

        let cancellable = await setupProviderAndWaitForReady(confidence: confidence)
        cancellable.cancel()

        let provider = ConfidenceFeatureProvider(confidence: confidence, initializationStrategy: .fetchAndActivate)
        let evaluation = try provider.getObjectEvaluation(
            key: "flag",
            defaultValue: Value.structure(["width": .integer(100), "color": .string("black")]),
            context: context)

        guard case let .structure(resultMap) = evaluation.value else {
            XCTFail("Expected structure value")
            return
        }

        XCTAssertEqual(resultMap["width"], .integer(200))
        XCTAssertEqual(resultMap["color"], .string("yellow"))
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(evaluation.reason, "targetingMatch")
    }

    func testProviderResolveStructHeterogenousExtraValueInFlag() async throws {
        let context = MutableContext(targetingKey: "user2")
        let storage = StorageMock()

        let resolvedValue = createResolvedValue(
            structure: [
                "width": .init(integer: 200),
                "color": .init(string: "yellow"),
                "error": .init(string: "Unknown")
            ]
        )
        let client = createFakeClient(resolvedValues: [resolvedValue])

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withStorage(storage: storage)
            .build()

        let cancellable = await setupProviderAndWaitForReady(confidence: confidence)
        cancellable.cancel()

        let provider = ConfidenceFeatureProvider(confidence: confidence, initializationStrategy: .fetchAndActivate)
        let evaluation = try provider.getObjectEvaluation(
            key: "flag",
            defaultValue: Value.structure(["width": .integer(100), "color": .string("black")]),
            context: context)

        guard case let .structure(resultMap) = evaluation.value else {
            XCTFail("Expected structure value")
            return
        }

        XCTAssertEqual(resultMap["width"], .integer(200))
        XCTAssertEqual(resultMap["color"], .string("yellow"))
        XCTAssertNil(resultMap["error"])
        XCTAssertEqual(evaluation.variant, "control")
        XCTAssertEqual(evaluation.reason, "targetingMatch")
    }

    func testProviderResolveStructHeterogenousExtraValueInDefaultValue() async throws {
        let context = MutableContext(targetingKey: "user2")
        let storage = StorageMock()

        let resolvedValue = createResolvedValue(
            structure: [
                "width": .init(integer: 200),
                "color": .init(string: "yellow")
            ]
        )
        let client = createFakeClient(resolvedValues: [resolvedValue])

        let confidence = Confidence.Builder(clientSecret: "test")
            .withContext(initialContext: ["targeting_key": .init(string: "user2")])
            .withFlagResolverClient(flagResolver: client)
            .withStorage(storage: storage)
            .build()

        let cancellable = await setupProviderAndWaitForReady(confidence: confidence)
        cancellable.cancel()

        let provider = ConfidenceFeatureProvider(confidence: confidence, initializationStrategy: .fetchAndActivate)
        let defaultStructure = Value.structure([
            "width": .integer(100),
            "color": .string("black"),
            "error": .string("Unknown")
        ])

        do {
            _ = try provider.getObjectEvaluation(
                key: "flag",
                defaultValue: defaultStructure,
                context: context)
            XCTFail("Expected an error to be thrown because 'error' key is missing from flag structure")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Type mismatch") ||
    error.localizedDescription.contains("missing required keys") ||
    error.localizedDescription.contains("error"))
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
