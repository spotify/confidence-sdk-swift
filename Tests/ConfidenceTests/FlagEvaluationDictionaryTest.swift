import Foundation
import XCTest

@testable import Confidence

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
class FlagEvaluationDictionaryTest: XCTestCase {
    func testDictionaryValidationWithCompatibleTypes() throws {
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

    func testDictionaryValidationWithIncompatibleTypes() throws {
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
            defaultValue: ["default": "value"],
            context: [:]
        )

        XCTAssertEqual(evaluation.reason, .error)
        if case let .typeMismatch(message) = evaluation.errorCode {
            XCTAssertEqual(message, "Default value key \'default\' not found in flag")
        } else {
            XCTFail("Expected .typeMismatch error code")
        }
        XCTAssertNotNil(evaluation.errorMessage)
        XCTAssertEqual(evaluation.value["default"], "value")
    }

    func testDictionaryValidationWithMissingKeys() throws {
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
    }

    func testDictionaryValidationWithExtraKeysAllowed() throws {
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

    func testDictionaryValidationWithTypeIncompatibilityButSameKeys() throws {
        let resolvedValue = ResolvedValue(
            value: .init(structure: [
                "key1": .init(integer: 42),
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
            defaultValue: ["key1": "value1", "key2": "value2"],
            context: [:]
        )

        XCTAssertEqual(evaluation.reason, .error)
        if case let .typeMismatch(message) = evaluation.errorCode {
            XCTAssertTrue(message.contains("incompatible type") || message.contains("cannot be cast"))
        } else {
            XCTFail("Expected .typeMismatch error code")
        }
        XCTAssertEqual(evaluation.value["key1"], "value1")
    }

    func testDictionaryValidationWithIntegerValues() throws {
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

    func testDictionaryValidationWithMixedValues() throws {
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

    func testDictionaryValidationUnexpectedType() throws {
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

    func testNonDictionaryTypesShouldNotTriggerValidation() throws {
        let resolvedValue = ResolvedValue(
            value: .init(string: "test_value"),
            flag: "test_flag",
            resolveReason: .match,
            shouldApply: true
        )

        let flagResolution = FlagResolution(
            context: [:],
            flags: [resolvedValue],
            resolveToken: ""
        )

        let evaluation: Evaluation<String> = flagResolution.evaluate(
            flagName: "test_flag",
            defaultValue: "default",
            context: [:]
        )

        XCTAssertEqual(evaluation.reason, .match)
        XCTAssertEqual(evaluation.value, "test_value")
        XCTAssertNil(evaluation.errorCode)
    }

    func testDictionaryValidationWithNestedStructuresAndMixedTypes() throws {
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

        validateTopLevelValues(evaluation)
        validateNestedProfile(evaluation)
        validateNestedSettings(evaluation)
        validateTags(evaluation)

        XCTAssertNil(evaluation.value["extraNestedField"])
    }

    func testDictionaryValidationWithNestedMissingKeys() throws {
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
            "profile": ["name": "Default", "age": 0, "email": "default@example.com"],
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
