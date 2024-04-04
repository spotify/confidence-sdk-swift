import Confidence
import XCTest

final class ConfidenceConfidenceValueTests: XCTestCase {
    func testNull() {
        let value = ConfidenceValue(null: ())
        XCTAssertTrue(value.isNull())
    }

    func testIntShouldConvertToInt() {
        let value = ConfidenceValue(integer: 3)
        XCTAssertEqual(value.asInteger(), 3)
    }

    func testDoubleShouldConvertToDouble() {
        let value = ConfidenceValue(double: 3.14)
        XCTAssertEqual(value.asDouble(), 3.14)
    }

    func testBoolShouldConvertToBool() {
        let value = ConfidenceValue(boolean: true)
        XCTAssertEqual(value.asBoolean(), true)
    }

    func testStringShouldConvertToString() {
        let value = ConfidenceValue(string: "test")
        XCTAssertEqual(value.asString(), "test")
    }

    func testStringShouldConvertToDate() throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = try XCTUnwrap(formatter.date(from: "2022-01-01 12:00:00"))
        let value = ConfidenceValue(timestamp: date)
        XCTAssertEqual(value.asDate(), date)
    }

    func testStringShouldConvertToDateComponents() {
        let dateComponents = DateComponents(year: 2024, month: 4, day: 3)
        let value = ConfidenceValue(date: dateComponents)
        XCTAssertEqual(value.asDateComponents(), dateComponents)
    }

    func testListShouldConvertToList() {
        let value = ConfidenceValue(integerList: [3, 4])
        XCTAssertEqual(value.asList(), [ConfidenceValue(integer: 3), ConfidenceValue(integer: 4)])
    }

    func testStructShouldConvertToStruct() {
        let value = ConfidenceValue(structure: [
            "field1": ConfidenceValue(integer: 3),
            "field2": ConfidenceValue(string: "test")
        ])
        XCTAssertEqual(value.asStructure(), [
            "field1": ConfidenceValue(integer: 3),
            "field2": ConfidenceValue(string: "test")
        ])
    }

    func testEmptyListAllowed() {
        let value = ConfidenceValue(integerList: [])
        XCTAssertEqual(value.asList(), [])
    }

    func testWrongTypeDoesntThrow() {
        let value = ConfidenceValue(null: ())
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
        let value = ConfidenceValue(string: "Test")
        XCTAssertFalse(value.isNull())
    }

    func testEncodeDecode() throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        let date = try XCTUnwrap(formatter.date(from: "2022-01-01 12:00:00"))
        let dateComponents = DateComponents(year: 2024, month: 4, day: 3)

        let value = ConfidenceValue(structure: ([
            "bool": ConfidenceValue(boolean: true),
            "date": ConfidenceValue(date: dateComponents),
            "double": ConfidenceValue(double: 4.5),
            "int": ConfidenceValue(integer: 3),
            "list": ConfidenceValue(integerList: [3, 5]),
            "null": ConfidenceValue(null: ()),
            "string": ConfidenceValue(string: "value"),
            "structure": ConfidenceValue(structure: ["int": ConfidenceValue(integer: 5)]),
            "timestamp": ConfidenceValue(timestamp: date),
        ]))
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let resultString = String(data: try encoder.encode(value), encoding: .utf8)
        let expectedString = """
        {\"bool\":true,
        \"date\":\"03-04-2024\",
        \"double\":4.5,
        \"int\":3,
        \"list\":[3,5],
        \"null\":null,
        \"string\":\"value\",
        \"structure\":{\"int\":5},
        \"timestamp\":\"2022-01-01T12:00:00Z\"}
        """.replacingOccurrences(of: "\n", with: "") // Newlines were added for readability

        XCTAssertEqual(resultString, expectedString)
    }
}
