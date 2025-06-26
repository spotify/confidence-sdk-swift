import Foundation
import XCTest

@testable import Confidence

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
class FlagEvaluationDictionaryTest: XCTestCase {
    func testBasicMatch() throws {
        let resolvedValue = ResolvedValue(
            value: .init(structure: [
                "key1": .init(string: "value1"),
                "key2": .init(string: "value2")
            ]),
            flag: "test_flag",
            resolveReason: .match,
            shouldApply: true
        )

        let flagResolution = FlagResolution(
            context: [:],
            flags: [resolvedValue],
            resolveToken: ""
        )

        let evaluation: Evaluation<[String: String]> = flagResolution.evaluate(
            flagName: "test_flag",
            defaultValue: ["key1": "defaultValue1", "key2": "defaultValue2"], // Use matching keys
            context: [:]
        )

        XCTAssertEqual(evaluation.reason, .match)
        XCTAssertEqual(evaluation.value["key1"], "value1")
        XCTAssertEqual(evaluation.value["key2"], "value2")
        XCTAssertNil(evaluation.errorCode)
    }

    func testIncompatibleTypes() throws {
        let resolvedValue = ResolvedValue(
            value: .init(structure: [
                "key1": .init(string: "value1"),
                "key2": .init(integer: 42)
            ]),
            flag: "test_flag",
            resolveReason: .match,
            shouldApply: true
        )

        let flagResolution = FlagResolution(
            context: [:],
            flags: [resolvedValue],
            resolveToken: ""
        )

        let evaluation: Evaluation<[String: String]> = flagResolution.evaluate(
            flagName: "test_flag",
            defaultValue: ["key1": "defaultValue1", "key2": "defaultValue2"],
            context: [:]
        )

        XCTAssertEqual(evaluation.reason, .error)
        if case let .typeMismatch(message) = evaluation.errorCode {
            XCTAssertEqual(message, "Default value key \'key2\' has incompatible type. Expected from flag is \'String\', got \'integer\'")
        } else {
            XCTFail("Expected .typeMismatch error code")
        }
        XCTAssertNotNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.value["key1"], "defaultValue1")
        XCTAssertEqual(evaluation.value["key2"], "defaultValue2")
    }

    func testMissingKeys() throws {
        let resolvedValue = ResolvedValue(
            value: .init(structure: [
                "wrongKey1": .init(string: "value1"),
                "wrongKey2": .init(string: "value2")
            ]),
            flag: "test_flag",
            resolveReason: .match,
            shouldApply: true
        )

        let flagResolution = FlagResolution(
            context: [:],
            flags: [resolvedValue],
            resolveToken: ""
        )

        let evaluation: Evaluation<[String: String]> = flagResolution.evaluate(
            flagName: "test_flag",
            defaultValue: ["expectedKey1": "value1", "expectedKey2": "value2"],
            context: [:]
        )

        XCTAssertEqual(evaluation.reason, .error)
        if case let .typeMismatch(message) = evaluation.errorCode {
            XCTAssertTrue(message.contains("not found in flag"))
        } else {
            XCTFail("Expected .typeMismatch error code")
        }
        XCTAssertEqual(evaluation.value["expectedKey1"], "value1")
        XCTAssertEqual(evaluation.value["expectedKey2"], "value2")
    }

    func testExtraKeysAllowed() throws {
        let resolvedValue = ResolvedValue(
            value: .init(structure: [
                "key1": .init(string: "value1"),
                "key2": .init(string: "value2"),
                "extraKey1": .init(string: "extra1"),
                "extraKey2": .init(integer: 42)
            ]),
            flag: "test_flag",
            resolveReason: .match,
            shouldApply: true
        )

        let flagResolution = FlagResolution(
            context: [:],
            flags: [resolvedValue],
            resolveToken: ""
        )

        let evaluation: Evaluation<[String: String]> = flagResolution.evaluate(
            flagName: "test_flag",
            defaultValue: ["key1": "default1", "key2": "default2"],
            context: [:]
        )

        XCTAssertEqual(evaluation.reason, .match)
        XCTAssertEqual(evaluation.value["key1"], "value1")
        XCTAssertEqual(evaluation.value["key2"], "value2")
        // Extra keys should not be included in the result
        XCTAssertNil(evaluation.value["extraKey1"])
        XCTAssertNil(evaluation.value["extraKey2"])
        XCTAssertNil(evaluation.errorCode)
    }

    func testIntegerValues() throws {
        let resolvedValue = ResolvedValue(
            value: .init(structure: [
                "count": .init(integer: 42),
                "total": .init(integer: 100)
            ]),
            flag: "test_flag",
            resolveReason: .match,
            shouldApply: true
        )

        let flagResolution = FlagResolution(
            context: [:],
            flags: [resolvedValue],
            resolveToken: ""
        )

        let evaluation: Evaluation<[String: Int]> = flagResolution.evaluate(
            flagName: "test_flag",
            defaultValue: ["count": 0, "total": 0],
            context: [:]
        )

        XCTAssertEqual(evaluation.reason, .match)
        XCTAssertEqual(evaluation.value["count"], 42)
        XCTAssertEqual(evaluation.value["total"], 100)
        XCTAssertNil(evaluation.errorCode)
    }

    func testMixedValues() throws {
        let resolvedValue = ResolvedValue(
            value: .init(structure: [
                "count": .init(integer: 42),
                "color": .init(string: "yellow")
            ]),
            flag: "test_flag",
            resolveReason: .match,
            shouldApply: true
        )

        let flagResolution = FlagResolution(
            context: [:],
            flags: [resolvedValue],
            resolveToken: ""
        )

        let evaluation: Evaluation<[String: Any]> = flagResolution.evaluate(
            flagName: "test_flag",
            defaultValue: ["count": 0, "color": "gray"],
            context: [:]
        )

        XCTAssertEqual(evaluation.reason, .match)
        XCTAssertEqual(evaluation.value["count"] as? Int, 42)
        XCTAssertEqual(evaluation.value["color"] as? String, "yellow")
        XCTAssertNil(evaluation.errorCode)
    }

    func testUnexpectedType() throws {
        let resolvedValue = ResolvedValue(
            value: .init(structure: [
                "count": .init(integer: 42),
                "color": .init(string: "yellow")
            ]),
            flag: "test_flag",
            resolveReason: .match,
            shouldApply: true
        )

        let flagResolution = FlagResolution(
            context: [:],
            flags: [resolvedValue],
            resolveToken: ""
        )

        let evaluation = flagResolution.evaluate(
            flagName: "test_flag",
            defaultValue: true, // Wrong type input
            context: [:]
        )

        XCTAssertEqual(evaluation.value, true)
        XCTAssertEqual(evaluation.reason, .error)
        if case let .typeMismatch(message) = evaluation.errorCode {
            XCTAssertTrue(message.contains("Expected a Dictionary as default value, but got a different type"))
        } else {
            XCTFail("Expected .typeMismatch error code for missing keys")
        }
    }

    func testNestedStructures() throws {
        let nestedUserProfile: ConfidenceStruct = [
            "name": ConfidenceValue(string: "John Doe"),
            "age": ConfidenceValue(integer: 30),
            "email": ConfidenceValue(string: "john@example.com")
        ]

        let nestedSettings: ConfidenceStruct = [
            "theme": ConfidenceValue(string: "dark"),
            "notifications": ConfidenceValue(boolean: true),
            "maxRetries": ConfidenceValue(integer: 3)
        ]

        let resolvedValue = ResolvedValue(
            value: ConfidenceValue(structure: [
                "profile": ConfidenceValue(structure: nestedUserProfile),
                "settings": ConfidenceValue(structure: nestedSettings),
                "isActive": ConfidenceValue(boolean: true),
                "score": ConfidenceValue(double: 95.5),
                "tags": ConfidenceValue(list: [
                    ConfidenceValue(string: "premium"),
                    ConfidenceValue(string: "verified")
                ]),
                "extraNestedField": ConfidenceValue(structure: [
                    "ignored": ConfidenceValue(string: "value")
                ])
            ]),
            flag: "test_flag",
            resolveReason: .match,
            shouldApply: true
        )

        let flagResolution = FlagResolution(
            context: [:],
            flags: [resolvedValue],
            resolveToken: ""
        )

        let defaultValue: [String: Any] = [
            "profile": ["name": "Default Name", "age": 0, "email": "default@example.com"],
            "settings": ["theme": "light", "notifications": false, "maxRetries": 1],
            "isActive": false,
            "score": 0.0,
            "tags": ["default"]
        ]

        let evaluation: Evaluation<[String: Any]> = flagResolution.evaluate(
            flagName: "test_flag",
            defaultValue: defaultValue,
            context: [:]
        )

        XCTAssertEqual(evaluation.reason, .match)
        XCTAssertNil(evaluation.errorCode)

        // These assert equality with the resolved value
        validateTopLevelValues(evaluation)
        validateNestedProfile(evaluation)
        validateNestedSettings(evaluation)
        validateTags(evaluation)

        XCTAssertNil(evaluation.value["extraNestedField"])
    }

    func testNestedMissingKeys() throws {
        let incompleteNestedProfile: ConfidenceStruct = [
            "name": ConfidenceValue(string: "John Doe")
            // Missing "age" and "email" keys
        ]

        let resolvedValue = ResolvedValue(
            value: ConfidenceValue(structure: [
                "profile": ConfidenceValue(structure: incompleteNestedProfile),
                "isActive": ConfidenceValue(boolean: true)
            ]),
            flag: "test_flag",
            resolveReason: .match,
            shouldApply: true
        )

        let flagResolution = FlagResolution(
            context: [:],
            flags: [resolvedValue],
            resolveToken: ""
        )

        let defaultValue: [String: Any] = [
            "isActive": false,
            "missingTopLevel": "required"
        ]

        let evaluation: Evaluation<[String: Any]> = flagResolution.evaluate(
            flagName: "test_flag",
            defaultValue: defaultValue,
            context: [:]
        )

        XCTAssertEqual(evaluation.reason, .error)
        if case let .typeMismatch(message) = evaluation.errorCode {
            XCTAssertTrue(message.contains("not found in flag"))
        } else {
            XCTFail("Expected .typeMismatch error code for missing keys")
        }

        XCTAssertEqual(evaluation.value["isActive"] as? Bool, false)
        XCTAssertEqual(evaluation.value["missingTopLevel"] as? String, "required")
    }

    func testNullFieldMerging() throws {
        let resolvedValue = ResolvedValue(
            variant: "control",
            value: .init(structure: [
                "active": .init(boolean: true),
                "message": .init(null: ())
            ]),
            flag: "flag",
            resolveReason: .match,
            shouldApply: true
        )

        let flagResolution = FlagResolution(
            context: [:],
            flags: [resolvedValue],
            resolveToken: ""
        )

        let evaluation: Evaluation<[String: Any]> = flagResolution.evaluate(
            flagName: "flag",
            defaultValue: [
                "active": false,
                "message": "default message"
            ],
            context: [:]
        )

        XCTAssertEqual(evaluation.reason, .match)
        XCTAssertEqual(evaluation.variant, "control")

        let result = evaluation.value
        XCTAssertEqual(result["active"] as? Bool, true)
        XCTAssertEqual(result["message"] as? String, "default message")
        XCTAssertNil(evaluation.errorCode)
    }

    // swiftlint:disable:next function_body_length
    func testAllConfidenceValueTypes() throws {
        let testDate = Date(timeIntervalSince1970: 1640995200) // 2022-01-01 00:00:00 UTC
        let testDateComponents = DateComponents(year: 2022, month: 1, day: 1)

        let resolvedValue = ResolvedValue(
            variant: "control",
            value: .init(structure: [
                "booleanValue": .init(boolean: true),
                "stringValue": .init(string: "resolved string"),
                "integerValue": .init(integer: 42),
                "doubleValue": .init(double: 3.14159),
                "dateValue": .init(timestamp: testDate),
                "dateComponentsValue": .init(date: testDateComponents),
                "booleanList": .init(booleanList: [true, false, true]),
                "stringList": .init(stringList: ["a", "b", "c"]),
                "integerList": .init(integerList: [1, 2, 3]),
                "doubleList": .init(doubleList: [1.1, 2.2, 3.3]),
                "dateList": .init(dateList: [testDateComponents, testDateComponents]),
                "timestampList": .init(timestampList: [testDate, testDate]),
                "nestedStruct": .init(structure: [
                    "nestedString": .init(string: "nested value"),
                    "nestedInteger": .init(integer: 100),
                    "nestedBoolean": .init(boolean: false)
                ])
            ]),
            flag: "flag",
            resolveReason: .match,
            shouldApply: true
        )

        let flagResolution = FlagResolution(
            context: [:],
            flags: [resolvedValue],
            resolveToken: ""
        )

        let evaluation: Evaluation<[String: Any]> = flagResolution.evaluate(
            flagName: "flag",
            defaultValue: [
                "booleanValue": false,
                "stringValue": "default string",
                "integerValue": 0,
                "doubleValue": 0.0,
                "dateValue": testDate,
                "dateComponentsValue": testDateComponents,
                "booleanList": [],
                "stringList": [],
                "integerList": [],
                "doubleList": [],
                "dateList": [],
                "timestampList": [],
                "nestedStruct": [
                    "nestedString": "default nested",
                    "nestedInteger": 0,
                    "nestedBoolean": true
                ]
            ],
            context: [:]
        )

        XCTAssertEqual(evaluation.reason, .match)
        XCTAssertEqual(evaluation.variant, "control")

        let result = evaluation.value
        XCTAssertEqual(result["booleanValue"] as? Bool, true)
        XCTAssertEqual(result["stringValue"] as? String, "resolved string")
        XCTAssertEqual(result["integerValue"] as? Int, 42)
        if let doubleValue = result["doubleValue"] as? Double {
            XCTAssertEqual(doubleValue, 3.14159, accuracy: 0.00001)
        } else {
            XCTFail("Expected doubleValue to be a Double")
        }
        XCTAssertEqual(result["dateValue"] as? Date, testDate)
        XCTAssertEqual(result["dateComponentsValue"] as? DateComponents, testDateComponents)
        XCTAssertEqual(result["booleanList"] as? [Bool], [true, false, true])
        XCTAssertEqual(result["stringList"] as? [String], ["a", "b", "c"])
        XCTAssertEqual(result["integerList"] as? [Int], [1, 2, 3])
        XCTAssertEqual(result["doubleList"] as? [Double], [1.1, 2.2, 3.3])
        XCTAssertEqual(result["dateList"] as? [DateComponents], [testDateComponents, testDateComponents])
        XCTAssertEqual(result["timestampList"] as? [Date], [testDate, testDate])
        if let nestedStruct = result["nestedStruct"] as? [String: Any] {
            XCTAssertEqual(nestedStruct["nestedString"] as? String, "nested value")
            XCTAssertEqual(nestedStruct["nestedInteger"] as? Int, 100)
            XCTAssertEqual(nestedStruct["nestedBoolean"] as? Bool, false)
        } else {
            XCTFail("Expected nestedStruct to be a dictionary")
        }
        XCTAssertNil(evaluation.errorCode)
    }

    // swiftlint:disable:next function_body_length
    func testAllNullsFallsBackToDefault() throws {
        let testDate = Date(timeIntervalSince1970: 1640995200) // 2022-01-01 00:00:00 UTC
        let testDateComponents = DateComponents(year: 2022, month: 1, day: 1)

        let resolvedValue = ResolvedValue(
            variant: "control",
            value: .init(structure: [
                "booleanValue": .init(null: ()),
                "stringValue": .init(null: ()),
                "integerValue": .init(null: ()),
                "doubleValue": .init(null: ()),
                "dateValue": .init(null: ()),
                "dateComponentsValue": .init(null: ()),
                "booleanList": .init(null: ()),
                "stringList": .init(null: ()),
                "integerList": .init(null: ()),
                "doubleList": .init(null: ()),
                "dateList": .init(null: ()),
                "timestampList": .init(null: ()),
                "nestedStruct": .init(null: ())
            ]),
            flag: "flag",
            resolveReason: .match,
            shouldApply: true
        )

        let flagResolution = FlagResolution(
            context: [:],
            flags: [resolvedValue],
            resolveToken: ""
        )

        let evaluation: Evaluation<[String: Any]> = flagResolution.evaluate(
            flagName: "flag",
            defaultValue: [
                "booleanValue": true,
                "stringValue": "default string",
                "integerValue": 42,
                "doubleValue": 3.14159,
                "dateValue": testDate,
                "dateComponentsValue": testDateComponents,
                "booleanList": [true, false, true],
                "stringList": ["a", "b", "c"],
                "integerList": [1, 2, 3],
                "doubleList": [1.1, 2.2, 3.3],
                "dateList": [testDateComponents, testDateComponents],
                "timestampList": [testDate, testDate],
                "nestedStruct": [
                    "nestedString": "default nested",
                    "nestedInteger": 0,
                    "nestedBoolean": true
                ]
            ],
            context: [:]
        )

        XCTAssertEqual(evaluation.reason, .match)
        XCTAssertEqual(evaluation.variant, "control")

        let result = evaluation.value
        XCTAssertEqual(result["booleanValue"] as? Bool, true)
        XCTAssertEqual(result["stringValue"] as? String, "default string")
        XCTAssertEqual(result["integerValue"] as? Int, 42)
        if let doubleValue = result["doubleValue"] as? Double {
            XCTAssertEqual(doubleValue, 3.14159, accuracy: 0.00001)
        } else {
            XCTFail("Expected doubleValue to be a Double")
        }
        XCTAssertEqual(result["dateValue"] as? Date, testDate)
        XCTAssertEqual(result["dateComponentsValue"] as? DateComponents, testDateComponents)
        XCTAssertEqual(result["booleanList"] as? [Bool], [true, false, true])
        XCTAssertEqual(result["stringList"] as? [String], ["a", "b", "c"])
        XCTAssertEqual(result["integerList"] as? [Int], [1, 2, 3])
        XCTAssertEqual(result["doubleList"] as? [Double], [1.1, 2.2, 3.3])
        XCTAssertEqual(result["dateList"] as? [DateComponents], [testDateComponents, testDateComponents])
        XCTAssertEqual(result["timestampList"] as? [Date], [testDate, testDate])
        if let nestedStruct = result["nestedStruct"] as? [String: Any] {
            XCTAssertEqual(nestedStruct["nestedString"] as? String, "default nested")
            XCTAssertEqual(nestedStruct["nestedInteger"] as? Int, 0)
            XCTAssertEqual(nestedStruct["nestedBoolean"] as? Bool, true)
        } else {
            XCTFail("Expected nestedStruct to be a dictionary")
        }
        XCTAssertNil(evaluation.errorCode)
    }

    // swiftlint:enable function_body_length

    func testHeterogenousMismatch() throws {
        let resolvedValue = ResolvedValue(
            variant: "control",
            value: .init(structure: [
                "width": .init(string: "200"),
                "color": .init(string: "yellow")
            ]),
            flag: "flag",
            resolveReason: .match,
            shouldApply: true
        )

        let flagResolution = FlagResolution(
            context: [:],
            flags: [resolvedValue],
            resolveToken: ""
        )

        let evaluation: Evaluation<[String: Int]> = flagResolution.evaluate(
            flagName: "flag",
            defaultValue: ["width": 100],
            context: [:]
        )

        XCTAssertEqual(evaluation.reason, .error)
        if case let .typeMismatch(message) = evaluation.errorCode {
            XCTAssertTrue(message.contains("incompatible type") || message.contains("cannot be cast"))
        } else {
            XCTFail("Expected .typeMismatch error code")
        }
        // Should return default values when there's an error
        XCTAssertEqual(evaluation.value["width"], 100)
    }

    // MARK: - Helper Methods

    private func validateTopLevelValues(_ evaluation: Evaluation<[String: Any]>) {
        XCTAssertEqual(evaluation.value["isActive"] as? Bool, true)
        XCTAssertEqual(evaluation.value["score"] as? Double, 95.5)
    }

    private func validateNestedProfile(_ evaluation: Evaluation<[String: Any]>) {
        guard let profile = evaluation.value["profile"] as? [String: Any] else {
            XCTFail("Profile should be a nested dictionary")
            return
        }
        XCTAssertEqual(profile["name"] as? String, "John Doe")
        XCTAssertEqual(profile["age"] as? Int, 30)
        XCTAssertEqual(profile["email"] as? String, "john@example.com")
    }

    private func validateNestedSettings(_ evaluation: Evaluation<[String: Any]>) {
        guard let settings = evaluation.value["settings"] as? [String: Any] else {
            XCTFail("Settings should be a nested dictionary")
            return
        }
        XCTAssertEqual(settings["theme"] as? String, "dark")
        XCTAssertEqual(settings["notifications"] as? Bool, true)
        XCTAssertEqual(settings["maxRetries"] as? Int, 3)
    }

    private func validateTags(_ evaluation: Evaluation<[String: Any]>) {
        guard let tags = evaluation.value["tags"] as? [Any] else {
            XCTFail("Tags should be a list")
            return
        }
        XCTAssertEqual(tags.count, 2)
        XCTAssertEqual(tags[0] as? String, "premium")
        XCTAssertEqual(tags[1] as? String, "verified")
    }
}
