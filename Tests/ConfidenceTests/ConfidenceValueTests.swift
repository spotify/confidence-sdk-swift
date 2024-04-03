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

    func testStringShouldConvertToDate() throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = try XCTUnwrap(formatter.date(from: "2022-01-01 12:00:00"))
        let value: ConfidenceValue = .timestamp(date)
        XCTAssertEqual(value.asDate(), date)
    }

    func testStringShouldConvertToDateComponents() {
        let dateComponents = DateComponents(year: 2024, month: 4, day: 3)
        let value: ConfidenceValue = .date(dateComponents)
        XCTAssertEqual(value.asDateComponents(), dateComponents)
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

    func testWrongTypeDoesntThrow() {
        let value = ConfidenceValue.null
        XCTAssertNil(value.asList())
        XCTAssertNil(value.asDouble())
        XCTAssertNil(value.asString())
        XCTAssertNil(value.asBoolean())
        XCTAssertNil(value.asInteger())
        XCTAssertNil(value.asStructure())
        XCTAssertNil(value.asDate())
        XCTAssertNil(value.asDateComponents())
    }

    func testIsNotNull() {
        let value = ConfidenceValue.string("Test")
        XCTAssertFalse(value.isNull())
    }

    func testEncodeDecode() throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = try XCTUnwrap(formatter.date(from: "2022-01-01 12:00:00"))
        let dateComponents = DateComponents(year: 2024, month: 4, day: 3)

        let value: ConfidenceValue = .structure([
            "bool": .boolean(true),
            "date": .date(dateComponents),
            "double": .double(4.5),
            "int": .integer(3),
            "list": .list([.boolean(false), .integer(4)]),
            "null": .null,
            "string": .string("value"),
            "structure": .structure(["int": .integer(5)]),
            "timestamp": .timestamp(date),
        ])
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let resultString = String(data: try encoder.encode(value), encoding: .utf8)
        let expectedString = """
        {\"bool\":true,
        \"date\":\"03-04-2024\",
        \"double\":4.5,
        \"int\":3,
        \"list\":[false,4],
        \"null\":null,
        \"string\":\"value\",
        \"structure\":{\"int\":5},
        \"timestamp\":\"2022-01-01T11:00:00Z\"}
        """.replacingOccurrences(of: "\n", with: "") // Newlines were added for readability

        XCTAssertEqual(resultString, expectedString)
    }
}
