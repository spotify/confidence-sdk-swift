import XCTest

@testable import Confidence

final class BaseUrlMapperTests: XCTestCase {
    func testCustomResolveBaseUrlWithTrailingSlashIsUsedForResolveAndApply() {
        let options = ConfidenceClientOptions(
            credentials: .clientSecret(secret: "test"),
            region: .usa,
            resolveBaseUrl: "http://localhost:8090/",
            timeoutIntervalForRequest: 10
        )

        XCTAssertEqual(
            BaseUrlMapper.from(options: options),
            "http://localhost:8090/v1/flags"
        )
    }

    func testCustomResolveBaseUrlWithoutTrailingSlashIsUsedForResolveAndApply() {
        let options = ConfidenceClientOptions(
            credentials: .clientSecret(secret: "test"),
            region: .usa,
            resolveBaseUrl: "http://localhost:8090",
            timeoutIntervalForRequest: 10
        )

        XCTAssertEqual(
            BaseUrlMapper.from(options: options),
            "http://localhost:8090/v1/flags"
        )
    }

    func testRegionalResolveBaseUrlIsUsedWithoutCustomUrl() {
        let options = ConfidenceClientOptions(
            credentials: .clientSecret(secret: "test"),
            region: .usa,
            timeoutIntervalForRequest: 10
        )

        XCTAssertEqual(
            BaseUrlMapper.from(options: options),
            "https://resolver.us.confidence.dev/v1/flags"
        )
    }

    func testBuilderStoresCustomResolveBaseUrl() {
        let builder = Confidence.Builder(clientSecret: "test")
            .withResolveBaseUrl(resolveBaseUrl: "http://localhost:8090")

        XCTAssertEqual(builder.resolveBaseUrl, "http://localhost:8090")
    }
}
