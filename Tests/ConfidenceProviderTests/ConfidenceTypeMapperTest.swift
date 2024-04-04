import Foundation
import Confidence
import OpenFeature
import XCTest

@testable import ConfidenceProvider

class ValueConverterTest: XCTestCase {
    func testContextConversion() throws {
        let openFeatureCtx = MutableContext(
            targetingKey: "userid",
            structure: MutableStructure(attributes: (["key": .string("value")])))
        let confidenceStruct = ConfidenceTypeMapper.from(ctx: openFeatureCtx)
        let expected = [
            "key": ConfidenceValue.string("value"),
            "targeting_key": ConfidenceValue.string("userid")
        ]
        XCTAssertEqual(confidenceStruct, expected)
    }

    func testValueConversion() throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = try XCTUnwrap(formatter.date(from: "2022-01-01 12:00:00"))

        let openFeatureValue = Value.structure([
            "key": .string("value"),
            "null": .null,
            "bool": .boolean(true),
            "int": .integer(3),
            "double": .double(4.5),
            "date": .date(date),
            "list": .list([.integer(3), .integer(5)]),
            "structure": .structure(["field1": .string("test"), "field2": .integer(12)]),
        ])

        let confidenceValue = ConfidenceTypeMapper.from(value: openFeatureValue)
        let expected = ConfidenceValue.structure([
            "key": .string("value"),
            "null": .null,
            "bool": .boolean(true),
            "int": .integer(3),
            "double": .double(4.5),
            "date": .timestamp(date),
            "list": .list([.integer(3), .integer(5)]),
            "structure": .structure(["field1": .string("test"), "field2": .integer(12)]),
        ])
        XCTAssertEqual(confidenceValue, expected)
    }
}
