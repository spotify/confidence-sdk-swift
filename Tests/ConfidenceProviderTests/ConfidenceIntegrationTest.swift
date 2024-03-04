import Foundation
import OpenFeature
import XCTest

@testable import Confidence

class ConfidenceIntegrationTests: XCTestCase {
    let clientToken: String? = ProcessInfo.processInfo.environment["CLIENT_TOKEN"]
    let resolveFlag = setResolveFlag()
    let storage: Storage = StorageMock()
    private var readyExpectation = XCTestExpectation(description: "Ready")

    private static func setResolveFlag() -> String {
        if let flag = ProcessInfo.processInfo.environment["TEST_FLAG_NAME"], !flag.isEmpty {
            return flag
        }
        return "swift-test-flag"
    }

    override func setUp() async throws {
        OpenFeatureAPI.shared.clearProvider()
        OpenFeatureAPI.shared.setEvaluationContext(evaluationContext: MutableContext())
        try await super.setUp()
    }

    func testConfidenceFeatureIntegration() throws {
        guard let clientToken = self.clientToken else {
            throw TestError.missingClientToken
        }

        withExtendedLifetime(
            OpenFeatureAPI.shared.observe().sink { event in
                if event == .ready {
                    self.readyExpectation.fulfill()
                }
            })
        {
            OpenFeatureAPI.shared.setProvider(
                provider:
                    ConfidenceFeatureProvider.Builder(credentials: .clientSecret(secret: clientToken))
                    .build())
            let client = OpenFeatureAPI.shared.getClient()
            wait(for: [readyExpectation], timeout: 5)

            self.readyExpectation = XCTestExpectation(description: "Ready (2)")
            let ctx = MutableContext(
                targetingKey: "user_foo",
                structure: MutableStructure(attributes: ["user": Value.structure(["country": Value.string("SE")])]))
            OpenFeatureAPI.shared.setEvaluationContext(evaluationContext: ctx)
            wait(for: [readyExpectation], timeout: 5)

            let intResult = client.getIntegerDetails(key: "\(resolveFlag).my-integer", defaultValue: 1)
            let boolResult = client.getBooleanDetails(key: "\(resolveFlag).my-boolean", defaultValue: false)

            XCTAssertEqual(intResult.flagKey, "\(resolveFlag).my-integer")
            XCTAssertEqual(intResult.reason, Reason.targetingMatch.rawValue)
            XCTAssertNotNil(intResult.variant)
            XCTAssertNil(intResult.errorCode)
            XCTAssertNil(intResult.errorMessage)
            XCTAssertEqual(boolResult.flagKey, "\(resolveFlag).my-boolean")
            XCTAssertEqual(boolResult.reason, Reason.targetingMatch.rawValue)
            XCTAssertNotNil(boolResult.variant)
            XCTAssertNil(boolResult.errorCode)
            XCTAssertNil(boolResult.errorMessage)
        }
    }

    func testConfidenceFeatureApplies() throws {
        guard let clientToken = self.clientToken else {
            throw TestError.missingClientToken
        }

        let flagApplier = FlagApplierMock()

        let confidenceFeatureProvider = ConfidenceFeatureProvider.Builder(
            credentials: .clientSecret(secret: clientToken)
        )
            .with(flagApplier: flagApplier)
            .with(storage: storage)
            .build()

        withExtendedLifetime(
            OpenFeatureAPI.shared.observe().sink { event in
                if event == .ready {
                    self.readyExpectation.fulfill()
                }
            })
        {
            OpenFeatureAPI.shared.setProvider(provider: confidenceFeatureProvider)
            wait(for: [readyExpectation], timeout: 5)

            self.readyExpectation = XCTestExpectation(description: "Ready (2)")
            let ctx = MutableContext(
                targetingKey: "user_foo",
                structure: MutableStructure(attributes: ["user": Value.structure(["country": Value.string("SE")])]))
            OpenFeatureAPI.shared.setEvaluationContext(evaluationContext: ctx)
            wait(for: [readyExpectation], timeout: 5)

            let client = OpenFeatureAPI.shared.getClient()
            OpenFeatureAPI.shared.setEvaluationContext(evaluationContext: ctx)

            let result = client.getIntegerDetails(key: "\(resolveFlag).my-integer", defaultValue: 1)

            XCTAssertEqual(result.reason, Reason.targetingMatch.rawValue)
            XCTAssertNotNil(result.variant)
            XCTAssertNil(result.errorCode)
            XCTAssertNil(result.errorMessage)

            wait(for: [flagApplier.applyExpectation], timeout: 5)
            XCTAssertEqual(flagApplier.applyCallCount, 1)
        }
    }

    func testConfidenceFeatureApplies_dateSupport() throws {
        guard let clientToken = self.clientToken else {
            throw TestError.missingClientToken
        }

        let flagApplier = FlagApplierMock()

        let confidenceFeatureProvider = ConfidenceFeatureProvider.Builder(
            credentials: .clientSecret(secret: clientToken)
        )
            .with(flagApplier: flagApplier)
            .with(storage: storage)
            .build()
        try withExtendedLifetime(
            OpenFeatureAPI.shared.observe().sink { event in
                if event == .ready {
                    self.readyExpectation.fulfill()
                }
            })
        {
            OpenFeatureAPI.shared.setProvider(provider: confidenceFeatureProvider)
            wait(for: [readyExpectation], timeout: 5)
            let date = try XCTUnwrap(convertStringToDate("2023-07-24T09:00:00Z"))

            // Given mutable context with date
            let ctx = MutableContext(
                targetingKey: "user_foo",
                structure: MutableStructure(attributes: [
                    "date": Value.date(date)
                ])
            )

            self.readyExpectation = XCTestExpectation(description: "Ready (2)")
            OpenFeatureAPI.shared.setEvaluationContext(evaluationContext: ctx)
            wait(for: [readyExpectation], timeout: 5)

            let client = OpenFeatureAPI.shared.getClient()

            // When evaluation of the flag happens using date context
            let result = client.getIntegerDetails(key: "\(resolveFlag).my-integer", defaultValue: 1)

            // Then there is targeting match (non-default targeting)
            XCTAssertEqual(result.reason, Reason.targetingMatch.rawValue)
            XCTAssertNotNil(result.variant)
            XCTAssertNil(result.errorCode)
            XCTAssertNil(result.errorMessage)

            wait(for: [flagApplier.applyExpectation], timeout: 5)
            XCTAssertEqual(flagApplier.applyCallCount, 1)
        }
    }

    func testConfidenceFeatureNoSegmentMatch() throws {
        guard let clientToken = self.clientToken else {
            throw TestError.missingClientToken
        }

        let flagApplier = FlagApplierMock()

        let confidenceFeatureProvider = ConfidenceFeatureProvider.Builder(
            credentials: .clientSecret(secret: clientToken)
        )
            .with(flagApplier: flagApplier)
            .with(storage: storage)
            .build()
        withExtendedLifetime(
            OpenFeatureAPI.shared.observe().sink { event in
                if event == .ready {
                    self.readyExpectation.fulfill()
                }
            })
        {
            OpenFeatureAPI.shared.setProvider(provider: confidenceFeatureProvider)
            wait(for: [readyExpectation], timeout: 5)

            self.readyExpectation = XCTestExpectation(description: "Ready (2)")
            let ctx = MutableContext(
                targetingKey: "user_foo",
                structure: MutableStructure(attributes: ["user": Value.structure(["country": Value.string("IT")])]))
            OpenFeatureAPI.shared.setEvaluationContext(evaluationContext: ctx)
            wait(for: [readyExpectation], timeout: 5)

            let client = OpenFeatureAPI.shared.getClient()

            let result = client.getIntegerDetails(key: "\(resolveFlag).my-integer", defaultValue: 1)

            XCTAssertEqual(result.value, 1)
            XCTAssertNil(result.variant)
            XCTAssertEqual(result.reason, Reason.defaultReason.rawValue)
            XCTAssertNil(result.errorCode)
            XCTAssertNil(result.errorMessage)

            wait(for: [flagApplier.applyExpectation], timeout: 5)
            XCTAssertEqual(flagApplier.applyCallCount, 1)
        }
    }

    // MARK: Helper

    private func convertStringToDate(_ dateString: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return dateFormatter.date(from: dateString)
    }
}

enum TestError: Error {
    case missingClientToken
}
