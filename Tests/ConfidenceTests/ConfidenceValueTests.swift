import Confidence
import XCTest

final class ConfidenceConfidenceValueTests: XCTestCase {
    func testNull() {
        let value = ConfidenceValue.null
        XCTAssertTrue(value.isNull())
    }

    func testIntShouldConvertToInt() {
        let value: ConfidenceValue = .integer(3)
        XCTAssertEqual(value.asInteger(), 3)
    }

    func testDoubleShouldConvertToDouble() {
        let value: ConfidenceValue = .double(3.14)
        XCTAssertEqual(value.asDouble(), 3.14)
    }

    func testBoolShouldConvertToBool() {
        let value: ConfidenceValue = .boolean(true)
        XCTAssertEqual(value.asBoolean(), true)
    }

    func testStringShouldConvertToString() {
        let value: ConfidenceValue = .string("test")
        XCTAssertEqual(value.asString(), "test")
    }

    func testListShouldConvertToList() {
        let value: ConfidenceValue = .list([.integer(3), .integer(4)])
        XCTAssertEqual(value.asList(), [.integer(3), .integer(4)])
    }

    func testStructShouldConvertToStruct() {
        let value: ConfidenceValue = .structure(["field1": .integer(3), "field2": .string("test")])
        XCTAssertEqual(value.asStructure(), ["field1": .integer(3), "field2": .string("test")])
    }

    func testEmptyListAllowed() {
        let value: ConfidenceValue = .list([])
        XCTAssertEqual(value.asList(), [])
    }

    func testEncodeDecode() throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = try XCTUnwrap(formatter.date(from: "2022-01-01 12:00:00"))

        let value: ConfidenceValue = .structure([
            "null": .null,
            "bool": .boolean(true),
            "int": .integer(3),
            "double": .double(4.5),
            "date": .date(date),
            "timestamp": .timestamp(date),
            "list": .list([.boolean(false), .integer(4)]),
            "structure": .structure(["int": .integer(5)]),
        ])

        let result = try JSONEncoder().encode(value)
        let decodedConfidenceValue = try JSONDecoder().decode(ConfidenceValue.self, from: result)

        XCTAssertEqual(value, decodedConfidenceValue)
    }

    func testDecodeConfidenceValue() throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = try XCTUnwrap(formatter.date(from: "2022-01-01 12:00:00"))

        let value: ConfidenceValue = .structure([
            "null": .null,
            "bool": .boolean(true),
            "int": .integer(3),
            "double": .double(4.5),
            "date": .date(date),
            "timestamp": .timestamp(date),
            "list": .list([.integer(3), .integer(5)]),
            "structure": .structure(["field1": .string("test"), "field2": .integer(12)]),
        ])
        let expected = TestConfidenceValue(
            bool: true,
            int: 3,
            double: 4.5,
            date: date,
            timestamp: date,
            list: [3, 5],
            structure: .init(field1: "test", field2: 12))

        let decodedConfidenceValue: TestConfidenceValue = try value.decode()

        XCTAssertEqual(decodedConfidenceValue, expected)
    }

    struct TestConfidenceValue: Codable, Equatable {
        var null: Bool?
        var bool: Bool
        var int: Int64
        var double: Double
        var date: Date
        var timestamp: Date
        var list: [Int64]
        var structure: TestSubConfidenceValue
    }

    struct TestSubConfidenceValue: Codable, Equatable {
        var field1: String
        var field2: Int64
    }
}
