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
            "key": ConfidenceValue(string: "value"),
            "targeting_key": ConfidenceValue(string: "userid")
        ]
        XCTAssertEqual(confidenceStruct, expected)
    }

    func testContextConversionWithLists() throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date1 = try XCTUnwrap(formatter.date(from: "2022-01-01 12:00:00"))
        let date2 = try XCTUnwrap(formatter.date(from: "2022-01-02 12:00:00"))

        let openFeatureCtx = MutableContext(
            targetingKey: "userid",
            structure: MutableStructure(attributes: ([
                "stringList": .list([.string("test1"), .string("test2")]),
                "booleanList": .list([.boolean(true), .boolean(false)]),
                "integerList": .list([.integer(11), .integer(33)]),
                "doubleList": .list([.double(3.14), .double(1.0)]),
                "dateList": .list([.date(date1), .date(date2)]),
                "nullList": .list([.null, .null]),
                "listList": .list([.list([.string("nested_value1")]), .list([.string("nested_value2")])]),
                "structList": .list([.structure(["test": .string("nested_test1")]), .structure(["test": .string("nested_test2")])])
            ])))
        let confidenceStruct = ConfidenceTypeMapper.from(ctx: openFeatureCtx)
        let expected = [
            "stringList": ConfidenceValue(stringList: ["test1", "test2"]),
            "booleanList": ConfidenceValue(booleanList: [true, false]),
            "integerList": ConfidenceValue(integerList: [11, 33]),
            "doubleList": ConfidenceValue(doubleList: [3.14, 1.0]),
            "dateList": ConfidenceValue(timestampList: [date1, date2]),
            "nullList": ConfidenceValue(nullList: [(), ()]),
            "listList": ConfidenceValue(nullList: [(), ()]),
            "structList": ConfidenceValue(nullList: [(), ()]),
            "targeting_key": ConfidenceValue(string: "userid")
        ]
        XCTAssertEqual(confidenceStruct, expected)
    }

    func testContextConversionWithHeterogenousLists() throws {
        let openFeatureCtx = MutableContext(
            targetingKey: "userid",
            structure: MutableStructure(attributes: (["key": .list([.string("test1"), .integer(1)])])))
        let confidenceStruct = ConfidenceTypeMapper.from(ctx: openFeatureCtx)
        let expected = [
            "key": ConfidenceValue(nullList: [()]),
            "targeting_key": ConfidenceValue(string: "userid")
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
        let expected = ConfidenceValue(structure: ([
            "key": ConfidenceValue(string: "value"),
            "null": ConfidenceValue(null: ()),
            "bool": ConfidenceValue(boolean: true),
            "int": ConfidenceValue(integer: 3),
            "double": ConfidenceValue(double: 4.5),
            "date": ConfidenceValue(timestamp: date),
            "list": ConfidenceValue(integerList: [3, 5]),
            "structure": ConfidenceValue(
                structure: [
                    "field1": ConfidenceValue(string: "test"),
                    "field2": ConfidenceValue(integer: 12)
                ])
        ]))
        XCTAssertEqual(confidenceValue, expected)
    }
}
