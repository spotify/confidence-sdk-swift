import Foundation
import OpenFeature
import XCTest

@testable import ConfidenceProvider

class OpenFeatureValueTypeMapperTest: XCTestCase {
    func testAsNativeDictionary() throws {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = try XCTUnwrap(formatter.date(from: "2022-01-01 12:00:00"))

        let openFeatureValue = OpenFeature.Value.structure([
            "stringValue": .string("hello"),
            "boolValue": .boolean(true),
            "intValue": .integer(42),
            "doubleValue": .double(3.14),
            "dateValue": .date(date),
            "nullValue": .null,
            "listValue": .list([.string("item1"), .string("item2"), .integer(123)]),
            "nestedStructure": .structure([
                "nestedString": .string("nested"),
                "nestedBool": .boolean(false)
            ])
        ])

        let nativeDict = openFeatureValue.asNativeDictionary()

        XCTAssertNotNil(nativeDict)
        guard let dict = nativeDict else { return }

        // Test basic types
        XCTAssertEqual(dict["stringValue"] as? String, "hello")
        XCTAssertEqual(dict["boolValue"] as? Bool, true)
        XCTAssertEqual(dict["intValue"] as? Int64, 42)
        XCTAssertEqual(dict["doubleValue"] as? Double ?? 0, 3.14, accuracy: 0.001)
        XCTAssertEqual(dict["dateValue"] as? Date, date)
        XCTAssertTrue(dict["nullValue"] is NSNull)

        // Test list
        let listValue = dict["listValue"] as? [Any]
        XCTAssertNotNil(listValue)
        XCTAssertEqual(listValue?.count, 3)
        XCTAssertEqual(listValue?[0] as? String, "item1")
        XCTAssertEqual(listValue?[1] as? String, "item2")
        XCTAssertEqual(listValue?[2] as? Int64, 123)

        // Test nested structure
        let nestedStruct = dict["nestedStructure"] as? [String: Any]
        XCTAssertNotNil(nestedStruct)
        XCTAssertEqual(nestedStruct?["nestedString"] as? String, "nested")
        XCTAssertEqual(nestedStruct?["nestedBool"] as? Bool, false)
    }

    func testAsNativeDictionaryWithNonStructure() {
        let stringValue = OpenFeature.Value.string("not a structure")
        let result = stringValue.asNativeDictionary()
        XCTAssertNil(result)
    }

    func testAsNativeType() throws {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = try XCTUnwrap(formatter.date(from: "2022-01-01 12:00:00"))

        // Test each type individually
        XCTAssertEqual(OpenFeature.Value.string("test").asNativeType() as? String, "test")
        XCTAssertEqual(OpenFeature.Value.boolean(true).asNativeType() as? Bool, true)
        XCTAssertEqual(OpenFeature.Value.integer(42).asNativeType() as? Int64, 42)
        XCTAssertEqual(OpenFeature.Value.double(3.14).asNativeType() as? Double ?? 0, 3.14, accuracy: 0.001)
        XCTAssertEqual(OpenFeature.Value.date(date).asNativeType() as? Date, date)
        XCTAssertTrue(OpenFeature.Value.null.asNativeType() is NSNull)

        // Test list
        let listValue = OpenFeature.Value.list([.string("a"), .integer(1)])
        let nativeList = listValue.asNativeType() as? [Any]
        XCTAssertNotNil(nativeList)
        XCTAssertEqual(nativeList?.count, 2)
        XCTAssertEqual(nativeList?[0] as? String, "a")
        XCTAssertEqual(nativeList?[1] as? Int64, 1)

        // Test structure
        let structValue = OpenFeature.Value.structure(["key": .string("value")])
        let nativeStruct = structValue.asNativeType() as? [String: Any]
        XCTAssertNotNil(nativeStruct)
        XCTAssertEqual(nativeStruct?["key"] as? String, "value")
    }

    func testFromNativeDictionary() throws {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = try XCTUnwrap(formatter.date(from: "2022-01-01 12:00:00"))

        let nativeDict: [String: Any] = [
            "stringValue": "hello",
            "boolValue": true,
            "intValue": 42,
            "int64Value": Int64(123),
            "doubleValue": 3.14,
            "dateValue": date,
            "nullValue": NSNull(),
            "listValue": ["item1", "item2", 123],
            "nestedStructure": [
                "nestedString": "nested",
                "nestedBool": false
            ]
        ]

        let openFeatureValue = try OpenFeature.Value.fromNativeDictionary(nativeDict)

        guard case let .structure(valueMap) = openFeatureValue else {
            XCTFail("Expected structure value")
            return
        }

        // Test converted types
        XCTAssertEqual(valueMap["stringValue"], .string("hello"))
        XCTAssertEqual(valueMap["boolValue"], .boolean(true))
        XCTAssertEqual(valueMap["intValue"], .integer(42))
        XCTAssertEqual(valueMap["int64Value"], .integer(123))
        XCTAssertEqual(valueMap["doubleValue"], .double(3.14))
        XCTAssertEqual(valueMap["dateValue"], .date(date))
        XCTAssertEqual(valueMap["nullValue"], .null)

        // Test list conversion
        guard case let .list(listValues) = valueMap["listValue"] else {
            XCTFail("Expected list value")
            return
        }
        XCTAssertEqual(listValues.count, 3)
        XCTAssertEqual(listValues[0], .string("item1"))
        XCTAssertEqual(listValues[1], .string("item2"))
        XCTAssertEqual(listValues[2], .integer(123))

        // Test nested structure
        guard case let .structure(nestedMap) = valueMap["nestedStructure"] else {
            XCTFail("Expected nested structure value")
            return
        }
        XCTAssertEqual(nestedMap["nestedString"], .string("nested"))
        XCTAssertEqual(nestedMap["nestedBool"], .boolean(false))
    }

    func testFromNativeType() throws {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = try XCTUnwrap(formatter.date(from: "2022-01-01 12:00:00"))

        // Test individual type conversions
        XCTAssertEqual(try OpenFeature.Value.fromNativeType("test"), .string("test"))
        XCTAssertEqual(try OpenFeature.Value.fromNativeType(true), .boolean(true))
        XCTAssertEqual(try OpenFeature.Value.fromNativeType(42), .integer(42))
        XCTAssertEqual(try OpenFeature.Value.fromNativeType(Int64(123)), .integer(123))
        XCTAssertEqual(try OpenFeature.Value.fromNativeType(3.14), .double(3.14))
        XCTAssertEqual(try OpenFeature.Value.fromNativeType(date), .date(date))
        XCTAssertEqual(try OpenFeature.Value.fromNativeType(NSNull()), .null)

        // Test array conversion
        let arrayValue = try OpenFeature.Value.fromNativeType(["a", 1, true])
        guard case let .list(listValues) = arrayValue else {
            XCTFail("Expected list value")
            return
        }
        XCTAssertEqual(listValues.count, 3)
        XCTAssertEqual(listValues[0], .string("a"))
        XCTAssertEqual(listValues[1], .integer(1))
        XCTAssertEqual(listValues[2], .boolean(true))

        // Test dictionary conversion
        let dictValue = try OpenFeature.Value.fromNativeType(["key": "value", "number": 42])
        guard case let .structure(structMap) = dictValue else {
            XCTFail("Expected structure value")
            return
        }
        XCTAssertEqual(structMap["key"], .string("value"))
        XCTAssertEqual(structMap["number"], .integer(42))
    }

    func testRoundTripConversion() throws {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = try XCTUnwrap(formatter.date(from: "2022-01-01 12:00:00"))

        let originalValue = OpenFeature.Value.structure([
            "stringValue": .string("hello"),
            "boolValue": .boolean(true),
            "intValue": .integer(42),
            "doubleValue": .double(3.14),
            "dateValue": .date(date),
            "nullValue": .null,
            "listValue": .list([.string("item1"), .integer(123)]),
            "nestedStructure": .structure([
                "nestedString": .string("nested"),
                "nestedBool": .boolean(false)
            ])
        ])

        // Convert to native dictionary and back
        let nativeDict = originalValue.asNativeDictionary()
        XCTAssertNotNil(nativeDict)

        guard let dict = nativeDict else {
            XCTFail("Expected non-nil native dictionary")
            return
        }
        let convertedBack = try OpenFeature.Value.fromNativeDictionary(dict)

        // Compare the original and converted back values
        XCTAssertEqual(originalValue, convertedBack)
    }
}
