import XCTest

@testable import ConfidenceDemoApp

final class ConfidenceDemoAppUITests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false

        let app = XCUIApplication()
        app.launchEnvironment = ["CLIENT_SECRET": ProcessInfo.processInfo.environment["CLIENT_SECRET"] ?? ""]
        app.launch()
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
    }

    func testGetFlagValue() {
        let app = XCUIApplication()
        let button = app.buttons["flag_button"]
        button.tap()
        let flag = app.staticTexts["flag_text"]
        XCTAssertEqual(flag.label, "Yellow")
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 17.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
