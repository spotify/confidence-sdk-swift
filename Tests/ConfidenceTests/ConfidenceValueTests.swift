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
        formatter.locale = Locale(identifier: "en_US_POSIX")
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

    func testListShouldConvertToList() throws {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        let date1 = try XCTUnwrap(formatter.date(from: "2022-01-01 12:00:00"))
        let dateComponents1 = DateComponents(year: 2024, month: 4, day: 3)
        let date2 = try XCTUnwrap(formatter.date(from: "2022-01-02 00:00:00"))
        let dateComponents2 = DateComponents(year: 2024, month: 4, day: 2)

        let booleanListValue = ConfidenceValue(booleanList: [true, false])
        let integerListValue = ConfidenceValue(integerList: [3, 4])
        let doubleListValue = ConfidenceValue(doubleList: [3.14, 4.0])
        let stringListValue = ConfidenceValue(stringList: ["val1", "val2"])
        let timestampListValue = ConfidenceValue(timestampList: [date1, date2])
        let dateListValue = ConfidenceValue(dateList: [dateComponents1, dateComponents2])

        XCTAssertEqual(booleanListValue.asList(), [ConfidenceValue(boolean: true), ConfidenceValue(boolean: false)])
        XCTAssertEqual(integerListValue.asList(), [ConfidenceValue(integer: 3), ConfidenceValue(integer: 4)])
        XCTAssertEqual(doubleListValue.asList(), [ConfidenceValue(double: 3.14), ConfidenceValue(double: 4.0)])
        XCTAssertEqual(stringListValue.asList(), [ConfidenceValue(string: "val1"), ConfidenceValue(string: "val2")])
        XCTAssertEqual(timestampListValue.asList(), [
            ConfidenceValue(timestamp: date1),
            ConfidenceValue(timestamp: date2)
        ])
        XCTAssertEqual(dateListValue.asList(), [
            ConfidenceValue(date: dateComponents1),
            ConfidenceValue(date: dateComponents2)
        ])
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
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(abbreviation: "EDT") // Verify TimeZone conversion
        let date = try XCTUnwrap(formatter.date(from: "2024-04-05 16:00:00"))
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
        let data = try encoder.encode(value)
        let resultString = try XCTUnwrap(String(data: data, encoding: .utf8))
        let resultData = try XCTUnwrap(resultString.data(using: .utf8))
        let decodedValue = try JSONDecoder().decode(ConfidenceValue.self, from: resultData)

        XCTAssertEqual(value, decodedValue)
    }
}
