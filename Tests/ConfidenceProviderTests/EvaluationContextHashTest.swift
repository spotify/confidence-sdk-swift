import OpenFeature
import XCTest

@testable import Confidence

final class MutableContextTests: XCTestCase {
    func testHashRespectsTargetingKey() throws {
        let ctx1 = MutableContext(targetingKey: "user1", structure: MutableStructure())
        let ctx2 = MutableContext(targetingKey: "user2", structure: MutableStructure())

        XCTAssertNotEqual(ctx1.hash(), ctx2.hash())
    }

    func testHashRespectsStructure() throws {
        let ctx1 = MutableContext(
            targetingKey: "", structure: MutableStructure(attributes: ["field": .list([.integer(3)])]))
        let ctx2 = MutableContext(
            targetingKey: "", structure: MutableStructure(attributes: ["field": .list([.integer(4)])]))

        XCTAssertNotEqual(ctx1.hash(), ctx2.hash())
    }

    func testHashIsEqualForEqualContext() throws {
        let ctx1 = MutableContext(
            targetingKey: "user1", structure: MutableStructure(attributes: ["field": .list([.integer(3)])]))
        let ctx2 = MutableContext(
            targetingKey: "user1", structure: MutableStructure(attributes: ["field": .list([.integer(3)])]))

        XCTAssertEqual(ctx1.hash(), ctx2.hash())
    }
}
