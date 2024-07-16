import Foundation
import OpenFeature
import XCTest

@testable import Confidence

class RemoteResolveConfidenceClientTest: XCTestCase {
    var flags: [String: MockedResolveClientURLProtocol.TestFlag] = [:]
    let resolvedFlag1 = MockedResolveClientURLProtocol.ResolvedTestFlag(
        variant: "control", value: .init(structure: ["size": .init(integer: 3)]))
    let resolvedFlag2 = MockedResolveClientURLProtocol.ResolvedTestFlag(
        variant: "treatment", value: .init(structure: ["size": .init(integer: 2)]))

    override func setUp() {
        self.flags = [
            "flags/flag1": .init(resolve: ["user1": resolvedFlag1]),
            "flags/flag2": .init(resolve: ["user1": resolvedFlag2]),
        ]

        MockedResolveClientURLProtocol.reset()

        super.setUp()
    }

    func testResolveMultipleFlagsSucceeds() async throws {
        let session = MockedResolveClientURLProtocol.mockedSession(flags: flags)

        let client = RemoteConfidenceResolveClient(
            options: .init(credentials: .clientSecret(secret: "test"), timeoutIntervalForRequest: 10),
            session: session,
            applyOnResolve: true,
            metadata: ConfidenceMetadata(name: "", version: "")
        )

        let context = ["targeting_key": ConfidenceValue(string: "user1")]

        let result = try await client.resolve(ctx: context)
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
