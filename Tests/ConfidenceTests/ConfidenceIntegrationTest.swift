import Foundation
import Common
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

    func testConfidenceFeatureIntegration() async throws {
        guard let clientToken = self.clientToken else {
            throw TestError.missingClientToken
        }

        let confidence = Confidence.Builder(clientSecret: clientToken).build()
        try await confidence.fetchAndActivate()

        let ctx: ConfidenceStruct = [
            "targeting_key": .init(string: "user_foo"),
            "user": .init(structure: ["country": .init(string: "SE")])
        ]

        let expectation = expectation(description: "context is synced")

        let cancellable = confidence.contextReconciliatedChanges.sink { contextHash in
            if contextHash == ctx.hash() {
                expectation.fulfill()
            }
        }

        confidence.putContext(context: ctx)

        await fulfillment(of: [expectation], timeout: 4)
        cancellable.cancel()


        let intResult = try confidence.getEvaluation(key: "\(resolveFlag).my-integer", defaultValue: 1)
        let boolResult = try confidence.getEvaluation(key: "\(resolveFlag).my-boolean", defaultValue: false)

        XCTAssertEqual(intResult.value, 3)
        XCTAssertEqual(intResult.reason, .match)
        XCTAssertNotNil(intResult.variant)
        XCTAssertNil(intResult.errorCode)
        XCTAssertNil(intResult.errorMessage)
        XCTAssertEqual(boolResult.value, true)
        XCTAssertEqual(boolResult.reason, .match)
        XCTAssertNotNil(boolResult.variant)
        XCTAssertNil(boolResult.errorCode)
        XCTAssertNil(boolResult.errorMessage)
    }

    func testConfidenceFeatureApplies() async throws {
        guard let clientToken = self.clientToken else {
            throw TestError.missingClientToken
        }

        let flagApplier = FlagApplierMock()

        let confidence = Confidence.Builder(clientSecret: clientToken)
            .withFlagApplier(flagApplier: flagApplier)
            .withStorage(storage: storage)
            .build()
        try await confidence.fetchAndActivate()

        let ctx: ConfidenceStruct = [
            "targeting_key": .init(string: "user_foo"),
            "user": .init(structure: ["country": .init(string: "SE")])
        ]

        let expectation = expectation(description: "context is synced")

        let cancellable = confidence.contextReconciliatedChanges.sink { contextHash in
            if contextHash == ctx.hash() {
                expectation.fulfill()
            }
        }
        confidence.putContext(context: ctx)
        await fulfillment(of: [expectation], timeout: 5)
        cancellable.cancel()
        let result = try confidence.getEvaluation(key: "\(resolveFlag).my-integer", defaultValue: 1)
        XCTAssertEqual(result.value, 3)
        XCTAssertEqual(result.reason, .match)
        XCTAssertNotNil(result.variant)
        XCTAssertNil(result.errorCode)
        XCTAssertNil(result.errorMessage)

        await fulfillment(of: [flagApplier.applyExpectation], timeout: 5)
        XCTAssertEqual(flagApplier.applyCallCount, 1)
    }

    func testConfidenceFeatureApplies_dateSupport() async throws {
        guard let clientToken = self.clientToken else {
            throw TestError.missingClientToken
        }

        let flagApplier = FlagApplierMock()

        let confidence = Confidence.Builder(clientSecret: clientToken)
            .withFlagApplier(flagApplier: flagApplier)
            .withStorage(storage: storage)
            .build()
        try await confidence.fetchAndActivate()

        let ctx: ConfidenceStruct = [
            "targeting_key": .init(string: "user_foo"),
            "user": .init(structure: ["country": .init(string: "SE")])
        ]

        let expectation = expectation(description: "context is synced")

        let cancellable = confidence.contextReconciliatedChanges.sink { contextHash in
            if contextHash == ctx.hash() {
                expectation.fulfill()
            }
        }
        confidence.putContext(context: ctx)
        await fulfillment(of: [expectation], timeout: 5)
        cancellable.cancel()
        // When evaluation of the flag happens using date context
        let result = try confidence.getEvaluation(key: "\(resolveFlag).my-integer", defaultValue: 1)
        // Then there is targeting match (non-default targeting)
        XCTAssertEqual(result.value, 3)
        XCTAssertEqual(result.reason, .match)
        XCTAssertNotNil(result.variant)
        XCTAssertNil(result.errorCode)
        XCTAssertNil(result.errorMessage)

        await fulfillment(of: [flagApplier.applyExpectation], timeout: 5)
        XCTAssertEqual(flagApplier.applyCallCount, 1)
    }

    func testConfidenceFeatureNoSegmentMatch() async throws {
        guard let clientToken = self.clientToken else {
            throw TestError.missingClientToken
        }

        let flagApplier = FlagApplierMock()

        let confidence = Confidence.Builder(clientSecret: clientToken)
            .withFlagApplier(flagApplier: flagApplier)
            .withStorage(storage: storage)
            .build()
        try await confidence.fetchAndActivate()

        let ctx: ConfidenceStruct = [
            "targeting_key": .init(string: "user_foo"),
            "user": .init(structure: ["country": .init(string: "IT")])
        ]

        let expectation = expectation(description: "context is synced")

        let cancellable = confidence.contextReconciliatedChanges.sink { contextHash in
            if contextHash == ctx.hash() {
                expectation.fulfill()
            }
        }
        confidence.putContext(context: ctx)
        await fulfillment(of: [expectation], timeout: 5)
        cancellable.cancel()
        // When evaluation of the flag happens using date context
        let result = try confidence.getEvaluation(key: "\(resolveFlag).my-integer", defaultValue: 1)
        // Then there is targeting match (non-default targeting)
        XCTAssertEqual(result.value, 1)
        XCTAssertEqual(result.reason, .noSegmentMatch)
        XCTAssertNotNil(result.variant)
        XCTAssertNil(result.errorCode)
        XCTAssertNil(result.errorMessage)

        await fulfillment(of: [flagApplier.applyExpectation], timeout: 5)
        XCTAssertEqual(flagApplier.applyCallCount, 1)
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
