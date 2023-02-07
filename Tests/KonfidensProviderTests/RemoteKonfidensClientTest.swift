import Foundation
import OpenFeature
import XCTest

@testable import KonfidensProvider

class RemoteKonfidensClientTest: XCTestCase {
    var flags: [String: MockedKonfidensClientURLProtocol.TestFlag] = [:]
    let resolvedFlag1 = MockedKonfidensClientURLProtocol.ResolvedTestFlag(
        variant: "control", value: .structure(["size": .integer(3)]))
    let resolvedFlag2 = MockedKonfidensClientURLProtocol.ResolvedTestFlag(
        variant: "treatment", value: .structure(["size": .integer(2)]))

    override func setUp() {
        self.flags = [
            "flags/flag1": .init(resolve: ["user1": resolvedFlag1]),
            "flags/flag2": .init(resolve: ["user1": resolvedFlag2]),
        ]

        MockedKonfidensClientURLProtocol.reset()

        super.setUp()
    }

    func testResolveSucceeds() throws {
        let session = MockedKonfidensClientURLProtocol.mockedSession(flags: flags)

        let client = RemoteKonfidensClient(
            options: .init(credentials: .clientSecret(secret: "test")), session: session, sendApplyEvent: true)

        let value = try client.resolve(flag: "flag1", ctx: MutableContext(targetingKey: "user1"))
        XCTAssertEqual(resolvedFlag1.value, value.resolvedValue.value)
        XCTAssertEqual(resolvedFlag1.variant, value.resolvedValue.variant)
    }

    func testBatchResolveSucceeds() throws {
        let session = MockedKonfidensClientURLProtocol.mockedSession(flags: flags)

        let client = RemoteKonfidensClient(
            options: .init(credentials: .clientSecret(secret: "test")), session: session, sendApplyEvent: true)

        let result = try client.batchResolve(ctx: MutableContext(targetingKey: "user1"))
        XCTAssertEqual(result.resolvedValues.count, 2)
        let sortedResultValues = result.resolvedValues.sorted { resolvedValue1, resolvedValue2 in
            resolvedValue1.flag < resolvedValue2.flag
        }
        XCTAssertEqual(resolvedFlag1.value, sortedResultValues[0].value)
        XCTAssertEqual(resolvedFlag1.variant, sortedResultValues[0].variant)
        XCTAssertEqual(resolvedFlag2.value, sortedResultValues[1].value)
        XCTAssertEqual(resolvedFlag2.variant, sortedResultValues[1].variant)
    }

    func testApplySucceeds() throws {
        let session = MockedKonfidensClientURLProtocol.mockedSession(flags: flags)

        let client = RemoteKonfidensClient(
            options: .init(credentials: .clientSecret(secret: "test")), session: session, sendApplyEvent: true)

        try client.apply(flag: "flag1", resolveToken: "test", appliedTime: Date.backport.now)
    }
}
