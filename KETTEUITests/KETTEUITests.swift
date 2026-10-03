import XCTest

final class KETTEUITests: XCTestCase {
    @MainActor
    func testNavigationSupportsBothLandscapeOrientations() {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launchArguments = ["-ui-testing-route-preview"]
        app.launch()
        XCTAssertTrue(app.buttons["startNavigation"].waitForExistence(timeout: 10))
        app.buttons["startNavigation"].tap()
        for orientation in [UIDeviceOrientation.landscapeLeft, .landscapeRight] {
            XCUIDevice.shared.orientation = orientation
            XCTAssertTrue(app.buttons["stopNavigation"].waitForExistence(timeout: 3))
            XCTAssertGreaterThan(app.frame.width, app.frame.height)
            XCTAssertTrue(app.staticTexts["nextManeuver"].isHittable)
            XCTAssertTrue(app.staticTexts["remainingDistance"].isHittable)
            XCTAssertTrue(app.buttons["stopNavigation"].isHittable)
            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screenshot.name = "Navigation-\(orientation.rawValue)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
        app.buttons["stopNavigation"].tap()
        XCTAssertTrue(app.buttons["startNavigation"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["startNavigation"].isHittable)
    }

    @MainActor
    func testRoutePreviewStartsAndStopsNavigation() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-route-preview", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()
        XCTAssertTrue(app.staticTexts["routeDistance"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["routeDistance"].label, "12,4 km")
        XCTAssertEqual(app.staticTexts["routeDuration"].label, "42 min")
        app.buttons["startNavigation"].tap()
        XCTAssertTrue(app.buttons["stopNavigation"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["startNavigation"].exists)
        XCTAssertTrue(app.staticTexts["nextManeuver"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["nextManeuver"].label, "Links abbiegen")
        XCTAssertEqual(app.staticTexts["remainingDistance"].label, "12,4 km")
        XCTAssertEqual(app.staticTexts["remainingDuration"].label, "42 min")
        app.buttons["stopNavigation"].tap()
        XCTAssertTrue(app.buttons["startNavigation"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testMapAndDestinationSearchAreAccessible() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.otherElements["mainMap"].waitForExistence(timeout: 10))
        let search = app.textFields["destinationSearch"]
        XCTAssertTrue(search.exists)
        search.tap()
        search.typeText("Berlin")
        XCTAssertTrue(app.buttons["cancelSearch"].exists)
        app.buttons["cancelSearch"].tap()
        XCTAssertEqual(search.value as? String, "Wohin?")
    }
}
