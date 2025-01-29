import XCTest
@testable import Confidence

final class ConfidenceDeviceInfoContextDecoratorTests: XCTestCase {

    func testEmptyConstructMakesNoOp() {
        let result = ConfidenceDeviceInfoContextDecorator().decorated(context: [:])
        XCTAssertEqual(result.count, 0)
    }

    func testAddDeviceInfo() {
        let result = ConfidenceDeviceInfoContextDecorator(withDeviceInfo: true).decorated(context: [:])
        XCTAssertEqual(result.count, 1)
        XCTAssertNotNil(result["device"])
        XCTAssertNotNil(result["device"]?.asStructure()?["model"])
        XCTAssertNotNil(result["device"]?.asStructure()?["type"])
        XCTAssertNotNil(result["device"]?.asStructure()?["manufacturer"])
    }

    func testAddLocale() {
        let result = ConfidenceDeviceInfoContextDecorator(withLocale: true).decorated(context: [:])
        XCTAssertEqual(result.count, 2)
        XCTAssertNotNil(result["locale"])
        XCTAssertNotNil(result["preferred_languages"])
    }

    func testAppendsData() {
        let result = ConfidenceDeviceInfoContextDecorator(withDeviceInfo: true).decorated(context: ["my_key": .init(double: 42.0)])
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result["my_key"]?.asDouble(), 42.0)
        XCTAssertNotNil(result["device"])
    }
}
