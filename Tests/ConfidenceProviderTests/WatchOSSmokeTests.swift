#if os(watchOS)
import Foundation
import ConfidenceProvider
import OpenFeature
import XCTest

@testable import Confidence

final class WatchOSSmokeTests: XCTestCase {
    func testCoreProviderFlowWithPersistedOfflineCache() async throws {
        let storage = MemoryStorage()
        let resolver = ContextResolver()
        let confidence = Confidence.Builder(clientSecret: "test", loggerLevel: .NONE)
            .withFlagResolverClient(flagResolver: resolver)
            .withStorage(storage: storage)
            .build()
        let provider = ConfidenceFeatureProvider(confidence: confidence)
        let api = OpenFeatureAPI()

        await api.setProviderAndWait(
            provider: provider,
            initialContext: ImmutableContext(targetingKey: "watch-user-1")
        )

        XCTAssertEqual(api.getProviderStatus(), .ready)
        XCTAssertEqual(
            api.getClient().getIntegerValue(key: "watch-flag.size", defaultValue: 0),
            3
        )

        await api.setEvaluationContextAndWait(
            evaluationContext: ImmutableContext(targetingKey: "watch-user-2")
        )

        XCTAssertEqual(api.getProviderStatus(), .ready)
        XCTAssertEqual(
            api.getClient().getIntegerValue(key: "watch-flag.size", defaultValue: 0),
            7
        )
        XCTAssertNoThrow(
            try confidence.track(
                eventName: "watch-smoke-test",
                data: ["source": ConfidenceValue(string: "watchOS")]
            )
        )

        let offlineConfidence = Confidence.Builder(clientSecret: "test", loggerLevel: .NONE)
            .withFlagResolverClient(flagResolver: FailingResolver())
            .withStorage(storage: storage)
            .build()
        let offlineProvider = ConfidenceFeatureProvider(
            confidence: offlineConfidence,
            initializationStrategy: .activateAndFetchAsync
        )
        let offlineAPI = OpenFeatureAPI()

        await offlineAPI.setProviderAndWait(
            provider: offlineProvider,
            initialContext: ImmutableContext(targetingKey: "watch-user-2")
        )

        let cachedDetails = offlineAPI.getClient().getIntegerDetails(
            key: "watch-flag.size",
            defaultValue: 0
        )
        XCTAssertEqual(offlineAPI.getProviderStatus(), .ready)
        XCTAssertEqual(cachedDetails.value, 7)
        XCTAssertEqual(cachedDetails.reason, ResolveReason.match.rawValue)
    }
}

private final class ContextResolver: ConfidenceResolveClient {
    func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
        let targetingKey = ctx["targeting_key"]?.asString()
        let size = targetingKey == "watch-user-2" ? 7 : 3
        return ResolvesResult(
            resolvedValues: [
                ResolvedValue(
                    variant: "control",
                    value: ConfidenceValue(structure: ["size": ConfidenceValue(integer: size)]),
                    flag: "watch-flag",
                    resolveReason: .match,
                    shouldApply: false
                )
            ],
            resolveToken: "watch-token"
        )
    }
}

private final class FailingResolver: ConfidenceResolveClient {
    func resolve(ctx: ConfidenceStruct) async throws -> ResolvesResult {
        throw ConfidenceError.internalError(message: "Offline")
    }
}

private final class MemoryStorage: Storage {
    private let queue = DispatchQueue(label: "com.confidence.watchos-smoke.storage")
    private var data: Data?

    func save(data: Encodable) throws {
        try queue.sync {
            self.data = try JSONEncoder().encode(data)
        }
    }

    func load<T>(defaultValue: T) throws -> T where T: Decodable {
        try queue.sync {
            guard let data else {
                return defaultValue
            }
            return try JSONDecoder().decode(T.self, from: data)
        }
    }

    func clear() throws {
        queue.sync {
            data = nil
        }
    }

    func isEmpty() -> Bool {
        queue.sync {
            data == nil
        }
    }
}
#endif
