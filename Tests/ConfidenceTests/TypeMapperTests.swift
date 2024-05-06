import Foundation
import OpenFeature
import XCTest

@testable import Confidence

class ValueConverterTest: XCTestCase {
    func testNetworkToConfidence() throws {
        let networkStruct = NetworkStruct.init(fields: [
            "string": .string("test1"),
            "boolean": .boolean(false),
            "int": .number(11),
            "double": .number(3.14),
            "list": .list([.boolean(true)]),
            "struct": .structure(NetworkStruct(fields: ["test": .string("value")])),
            "null": .null
        ])
        let confidenceStruct = try TypeMapper.convert(structure: networkStruct, schema: StructFlagSchema(schema: [
            "string": .stringSchema,
            "boolean": .boolSchema,
            "int": .intSchema,
            "double": .doubleSchema,
            "list": .listSchema(FlagSchema.boolSchema),
            "struct": .structSchema(StructFlagSchema.init(schema: ["test": .stringSchema])),
            "null": .stringSchema
        ]))
        let expected = [
            "string": ConfidenceValue(string: "test1"),
            "boolean": ConfidenceValue(boolean: false),
            "int": ConfidenceValue(integer: 11),
            "double": ConfidenceValue(double: 3.14),
            "list": ConfidenceValue(list: [ConfidenceValue(boolean: true)]),
            "struct": ConfidenceValue(structure: ["test": ConfidenceValue(string: "value")]),
            "null": ConfidenceValue.init(null: ())
        ]
        XCTAssertEqual(confidenceStruct, expected)
    }

    func testConfidenceToNetwork() throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = try XCTUnwrap(formatter.date(from: "2022-01-01 12:00:00"))

        let confidenceStruct: ConfidenceStruct = [
            "string": ConfidenceValue(string: "test1"),
            "boolean": ConfidenceValue(boolean: false),
            "int": ConfidenceValue(integer: 11),
            "double": ConfidenceValue(double: 3.14),
            "list": ConfidenceValue(list: [ConfidenceValue(boolean: true)]),
            "struct": ConfidenceValue(structure: ["test": ConfidenceValue(string: "value")]),
            "date": ConfidenceValue(date: DateComponents(year: 1990, month: 4, day: 2)),
            "timestamp": ConfidenceValue(timestamp: date),
            "null": ConfidenceValue.init(null: ())
        ]
        let networkStruct = TypeMapper.convert(structure: confidenceStruct)
        let expectedNetworkStruct = NetworkStruct.init(fields: [
            "string": .string("test1"),
            "boolean": .boolean(false),
            "int": .number(11),
            "double": .number(3.14),
            "list": .list([.boolean(true)]),
            "struct": .structure(NetworkStruct(fields: ["test": .string("value")])),
            "date": .string("1990-04-02"),
            "timestamp": .string("2022-01-01T11:00:00Z"),
            "null": .null
        ])
        XCTAssertEqual(networkStruct, expectedNetworkStruct)
    }

    func testNetworkToConfidenceLists() throws {
        let networkStruct = NetworkStruct.init(fields: [
            "stringList": .list([.string("test1"), .string("test2")]),
            "booleanList": .list([.boolean(true), .boolean(false)]),
            "integerList": .list([.number(11), .number(0)]),
            "doubleList": .list([.number(3.14), .number(1.0)]),
            "nullList": .list([.null, .null])
        ])
        let confidenceStruct = try TypeMapper.convert(structure: networkStruct, schema: StructFlagSchema(schema: [
            "stringList": .listSchema(FlagSchema.stringSchema),
            "booleanList": .listSchema(FlagSchema.boolSchema),
            "integerList": .listSchema(FlagSchema.intSchema),
            "doubleList": .listSchema(FlagSchema.doubleSchema),
            "nullList": .listSchema(FlagSchema.stringSchema)
        ]))
        let expected = [
            "stringList": ConfidenceValue(stringList: ["test1", "test2"]),
            "booleanList": ConfidenceValue(booleanList: [true, false]),
            "integerList": ConfidenceValue(integerList: [11, 0]),
            "doubleList": ConfidenceValue(doubleList: [3.14, 1.0]),
            "nullList": ConfidenceValue(nullList: [(), ()]),
        ]
        XCTAssertEqual(confidenceStruct, expected)
    }
}
