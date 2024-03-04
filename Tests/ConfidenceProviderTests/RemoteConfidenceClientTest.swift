import Foundation
import OpenFeature
import XCTest

@testable import Confidence

class RemoteConfidenceClientTest: XCTestCase {
    var flags: [String: MockedConfidenceClientURLProtocol.TestFlag] = [:]
    let resolvedFlag1 = MockedConfidenceClientURLProtocol.ResolvedTestFlag(
        variant: "control", value: .structure(["size": .integer(3)]))
    let resolvedFlag2 = MockedConfidenceClientURLProtocol.ResolvedTestFlag(
        variant: "treatment", value: .structure(["size": .integer(2)]))

    override func setUp() {
        self.flags = [
            "flags/flag1": .init(resolve: ["user1": resolvedFlag1]),
            "flags/flag2": .init(resolve: ["user1": resolvedFlag2]),
        ]

        MockedConfidenceClientURLProtocol.reset()

        super.setUp()
    }

    func testResolveMultipleFlagsSucceeds() async throws {
        let session = MockedConfidenceClientURLProtocol.mockedSession(flags: flags)
        let flagApplier = FlagApplierMock()

        let client = RemoteConfidenceClient(
            options: .init(credentials: .clientSecret(secret: "test")),
            session: session,
            applyOnResolve: true,
            flagApplier: flagApplier,
            metadata: ConfidenceMetadata()
        )

        let result = try await client.resolve(ctx: MutableContext(targetingKey: "user1"))
        XCTAssertEqual(result.resolvedValues.count, 2)
        let sortedResultValues = result.resolvedValues.sorted { resolvedValue1, resolvedValue2 in
            resolvedValue1.flag < resolvedValue2.flag
        }
        XCTAssertEqual(resolvedFlag1.value, sortedResultValues[0].value)
        XCTAssertEqual(resolvedFlag1.variant, sortedResultValues[0].variant)
        XCTAssertEqual(resolvedFlag2.value, sortedResultValues[1].value)
        XCTAssertEqual(resolvedFlag2.variant, sortedResultValues[1].variant)
    }
}
