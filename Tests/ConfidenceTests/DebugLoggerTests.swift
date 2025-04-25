import Foundation
import OSLog
import XCTest

@testable import Confidence

/// A testable debug logger that captures log output
class TestableDebugLogger: DebugLoggerImpl {
    var capturedLogs: [(level: LoggerLevel, message: String)] = []

    override func log(messageLevel: LoggerLevel, message: String) {
        capturedLogs.append((level: messageLevel, message: message))
        super.log(messageLevel: messageLevel, message: message)
    }

    func clearCapturedLogs() {
        capturedLogs.removeAll()
    }
}

class DebugLoggerTests: XCTestCase {
    var debugLogger: TestableDebugLogger!

    override func setUp() {
        super.setUp()
        debugLogger = TestableDebugLogger(loggerLevel: .DEBUG, clientKey: "my-client-key")
        debugLogger.capturedLogs.removeAll()
    }

    override func tearDown() {
        debugLogger = nil
        super.tearDown()
    }

    func testLogResolveDebugURL() {
        let context: ConfidenceStruct = [
            "user_id": .init(string: "123"),
            "email": .init(string: "test@test.com"),
        ]

        debugLogger.logResolveDebugURL(flagName: "my-flag", context: context)
        XCTAssertFalse(debugLogger.capturedLogs.isEmpty, "No logs were captured")
        let debugLog = debugLogger.capturedLogs.first { $0.level == .DEBUG && $0.message.contains("Check your flag evaluation for my-flag") }
        XCTAssertNotNil(debugLog, "Expected debug log not found")
        // Extract base64 string from log message
        guard let base64String = debugLog?.message.split(separator: "'").dropFirst().first else {
            XCTFail("Could not extract base64 string from log message")
            return
        }

        // Decode base64 to JSON string
        guard let decodedData = Data(base64Encoded: String(base64String)),
              let decodedString = String(data: decodedData, encoding: .utf8),
              let jsonData = decodedString.data(using: .utf8),
              let decodedJson = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        else {
            XCTFail("Could not decode base64 string to JSON")
            return
        }

        // Verify decoded JSON structure
        XCTAssertEqual(decodedJson["clientKey"] as? String, "my-client-key")
        XCTAssertEqual(decodedJson["flag"] as? String, "flags/my-flag")

        guard let contextDict = decodedJson["context"] as? [String: String] else {
            XCTFail("Context not found in decoded JSON")
            return
        }

        XCTAssertEqual(contextDict["user_id"], "123")
        XCTAssertEqual(contextDict["email"], "test@test.com")
    }

    func testLogResolveDebugURLWithEmptyContext() {
        let context: ConfidenceStruct = [:]

        debugLogger.logResolveDebugURL(flagName: "my-flag", context: context)
        XCTAssertFalse(debugLogger.capturedLogs.isEmpty, "No logs were captured")
        let debugLog = debugLogger.capturedLogs.first { $0.level == .DEBUG && $0.message.contains("Check your flag evaluation for my-flag") }
        XCTAssertNotNil(debugLog, "Expected debug log not found")

        guard let base64String = debugLog?.message.split(separator: "'").dropFirst().first else {
            XCTFail("Could not extract base64 string from log message")
            return
        }

        guard let decodedData = Data(base64Encoded: String(base64String)),
              let decodedString = String(data: decodedData, encoding: .utf8),
              let jsonData = decodedString.data(using: .utf8),
              let decodedJson = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        else {
            XCTFail("Could not decode base64 string to JSON")
            return
        }

        XCTAssertEqual(decodedJson["clientKey"] as? String, "my-client-key")
        XCTAssertEqual(decodedJson["flag"] as? String, "flags/my-flag")

        guard let contextDict = decodedJson["context"] as? [String: Any] else {
            XCTFail("Context not found in decoded JSON")
            return
        }

        XCTAssertTrue(contextDict.isEmpty, "Context should be empty")
    }

    func testLogResolveDebugURLWithComplexContext() {
        let context: ConfidenceStruct = [
            "user_id": .init(string: "123"),
            "email": .init(string: "test@test.com"),
            "age": .init(integer: 25),
            "premium": .init(boolean: true),
            "score": .init(double: 98.6),
            "preferences": .init(structure: [
                "theme": .init(string: "dark"),
                "notifications": .init(boolean: true),
                "favorites": .init(list: [
                    .init(string: "item1"),
                    .init(string: "item2"),
                ]),
            ]),
        ]

        debugLogger.logResolveDebugURL(flagName: "my-flag", context: context)
        XCTAssertFalse(debugLogger.capturedLogs.isEmpty, "No logs were captured")
        let debugLog = debugLogger.capturedLogs.first { $0.level == .DEBUG && $0.message.contains("Check your flag evaluation for my-flag") }
        XCTAssertNotNil(debugLog, "Expected debug log not found")

        guard let base64String = debugLog?.message.split(separator: "'").dropFirst().first else {
            XCTFail("Could not extract base64 string from log message")
            return
        }

        guard let decodedData = Data(base64Encoded: String(base64String)),
              let decodedString = String(data: decodedData, encoding: .utf8),
              let jsonData = decodedString.data(using: .utf8),
              let decodedJson = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        else {
            XCTFail("Could not decode base64 string to JSON")
            return
        }

        XCTAssertEqual(decodedJson["clientKey"] as? String, "my-client-key")
        XCTAssertEqual(decodedJson["flag"] as? String, "flags/my-flag")

        guard let contextDict = decodedJson["context"] as? [String: Any] else {
            XCTFail("Context not found in decoded JSON")
            return
        }

        XCTAssertEqual(contextDict["user_id"] as? String, "123")
        XCTAssertEqual(contextDict["email"] as? String, "test@test.com")
        XCTAssertEqual(contextDict["age"] as? Int, 25)
        XCTAssertEqual(contextDict["premium"] as? Bool, true)
        XCTAssertEqual(contextDict["score"] as? Double, 98.6)

        guard let preferences = contextDict["preferences"] as? [String: Any] else {
            XCTFail("Preferences not found in context")
            return
        }

        XCTAssertEqual(preferences["theme"] as? String, "dark")
        XCTAssertEqual(preferences["notifications"] as? Bool, true)

        guard let favorites = preferences["favorites"] as? [String] else {
            XCTFail("Favorites not found in preferences")
            return
        }

        XCTAssertEqual(favorites, ["item1", "item2"])
    }
}
