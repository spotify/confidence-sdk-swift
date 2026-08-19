import Foundation
import XCTest

@testable import Confidence

@available(macOS 13.0, iOS 16.0, *)
final class CancellationStorageRaceTest: XCTestCase {
    func testSupersededSaveCannotOverwriteLatestResolution() async throws {
        let firstSaveStarted = expectation(description: "first save started")
        let releaseFirstSave = DispatchSemaphore(value: 0)
        defer { releaseFirstSave.signal() }
        let storage = BlockingSaveStorage(
            firstSaveStarted: firstSaveStarted,
            releaseFirstSave: releaseFirstSave
        )
        let confidence = Confidence.Builder(clientSecret: "test")
            .withFlagResolverClient(flagResolver: ImmediateTargetingClient())
            .withStorage(storage: storage)
            .build()

        let first = Task {
            await confidence.applyContext(
                context: ["targeting_key": .init(string: "user1")],
                strategy: .fetchAndActivate
            )
        }
        await fulfillment(of: [firstSaveStarted], timeout: 1)

        let second = await confidence.reconcileContext(
            context: ["targeting_key": .init(string: "user2")]
        )
        guard case .success = second else {
            XCTFail("second reconciliation should succeed")
            return
        }

        releaseFirstSave.signal()
        _ = await first.value

        try confidence.activate()
        XCTAssertEqual(confidence.getEvaluation(key: "flag.size", defaultValue: 0).value, 7)
    }
}

private final class ImmediateTargetingClient: ConfidenceResolveClient {
    func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
        let size = ctx["targeting_key"]?.asString() == "user2" ? 7 : 3
        return .init(
            resolvedValues: [
                ResolvedValue(
                    variant: "control",
                    value: .init(structure: ["size": .init(integer: size)]),
                    flag: "flag",
                    resolveReason: .match,
                    shouldApply: true
                )
            ],
            resolveToken: "token"
        )
    }
}

private final class BlockingSaveStorage: Storage {
    private let lock = NSLock()
    private let firstSaveStarted: XCTestExpectation
    private let releaseFirstSave: DispatchSemaphore
    private var resolution: FlagResolution?

    init(firstSaveStarted: XCTestExpectation, releaseFirstSave: DispatchSemaphore) {
        self.firstSaveStarted = firstSaveStarted
        self.releaseFirstSave = releaseFirstSave
    }

    func save(data: Encodable) throws {
        let newResolution = try XCTUnwrap(data as? FlagResolution)
        if newResolution.context["targeting_key"]?.asString() == "user1" {
            firstSaveStarted.fulfill()
            releaseFirstSave.wait()
        }
        lock.lock()
        resolution = newResolution
        lock.unlock()
    }

    func load<T>(defaultValue: T) throws -> T where T: Decodable {
        lock.lock()
        let value = resolution
        lock.unlock()
        return (value as? T) ?? defaultValue
    }

    func clear() throws {
        lock.lock()
        resolution = nil
        lock.unlock()
    }

    func isEmpty() -> Bool {
        lock.lock()
        let empty = resolution == nil
        lock.unlock()
        return empty
    }
}
