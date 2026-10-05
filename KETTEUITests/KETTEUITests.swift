import XCTest

final class KETTEUITests: XCTestCase {
    @MainActor
    func testFollowArrowTracksLocationAfterReturningToPreview() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-route-preview", "-ui-testing-moving-location", "-ui-testing-planning-location", "-ui-testing-position-camera"]
        app.launch()
        XCTAssertTrue(app.buttons["startNavigation"].waitForExistence(timeout: 10))
        app.buttons["startNavigation"].tap()
        app.buttons["stopNavigation"].tap()
        app.buttons["resumeFollowing"].tap()
        let map = app.otherElements["mainMap"]
        let initial = map.value as? String
        let moved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (map.value as? String) != initial
        }, object: map)
        XCTAssertEqual(XCTWaiter.wait(for: [moved], timeout: 4), .completed)
        XCTAssertEqual(app.buttons["resumeFollowing"].value as? String, "Active")
    }

    @MainActor
    func testReroutingKeepsSummaryAndCyclistPositionVisible() {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments = ["-ui-testing-route-preview", "-ui-testing-moving-location", "-ui-testing-perpendicular-location", "-ui-testing-reroute-error"]
        app.launch()
        XCTAssertTrue(app.buttons["startNavigation"].waitForExistence(timeout: 10))
        app.buttons["startNavigation"].tap()
        let marker = app.otherElements["fixedCyclist"]
        let initialY = marker.frame.midY
        XCTAssertTrue(app.staticTexts["Recalculating route …"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["remainingDuration"].isHittable)
        XCTAssertTrue(app.staticTexts["remainingDistance"].isHittable)
        XCTAssertEqual(marker.frame.midY, initialY, accuracy: 1)
        XCTAssertTrue(app.staticTexts["Could not calculate route."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["remainingDuration"].isHittable)
        XCTAssertTrue(app.buttons["stopNavigation"].isHittable)
        XCTAssertEqual(marker.frame.midY, initialY, accuracy: 1)
    }

    @MainActor
    func testNavigationCameraTracksMovementPerpendicularToRoute() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-route-preview", "-ui-testing-moving-location", "-ui-testing-perpendicular-location", "-ui-testing-position-camera"]
        app.launch()
        XCTAssertTrue(app.buttons["startNavigation"].waitForExistence(timeout: 10))
        app.buttons["startNavigation"].tap()
        let map = app.otherElements["mainMap"]
        let moved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let value = map.value as? String,
                  let latitude = Double(value.split(separator: "|").first.map(String.init) ?? "") else { return false }
            return latitude > 52.5201
        }, object: map)
        XCTAssertEqual(XCTWaiter.wait(for: [moved], timeout: 3), .completed, "Camera: \(String(describing: map.value))")
    }

    @MainActor
    func testSearchCoversMapAndReturnsToMapAfterCancelOrSelection() {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launchArguments = ["-ui-testing-search"]
        app.launch()
        let search = app.buttons["destinationSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        XCTAssertTrue(app.otherElements["destinationSearchScreen"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.links["BRouter"].exists)
        XCTAssertTrue(app.links["© OpenStreetMap contributors"].exists)
        let activeSearch = app.textFields["activeDestinationSearch"]
        activeSearch.typeText("Potsdamer")
        XCTAssertTrue(app.buttons["Potsdamer Platz, Berlin"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.otherElements["mainMap"].isHittable)
        XCTAssertEqual(app.otherElements["destinationSearchScreen"].frame.width, app.frame.width, accuracy: 1)
        let portrait = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        portrait.name = "Full-screen-search-portrait"
        portrait.lifetime = .keepAlways
        add(portrait)
        app.buttons["cancelSearch"].tap()
        XCTAssertTrue(app.otherElements["mainMap"].isHittable)
        XCTAssertEqual(search.label, "Where to?")
        XCUIDevice.shared.orientation = .landscapeLeft
        search.tap()
        activeSearch.typeText("Potsdamer")
        XCTAssertFalse(app.otherElements["mainMap"].isHittable)
        XCTAssertEqual(app.otherElements["destinationSearchScreen"].frame.width, app.frame.width, accuracy: 1)
        let landscape = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        landscape.name = "Full-screen-search-landscape"
        landscape.lifetime = .keepAlways
        add(landscape)
        app.buttons["Potsdamer Platz, Berlin"].tap()
        XCTAssertTrue(app.buttons["startNavigation"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["destinationSearchScreen"].exists)
        XCTAssertTrue(app.otherElements["mainMap"].isHittable)
    }

    @MainActor
    func testLaunchCentersMapWhenFirstLocationArrives() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-launch-location"]
        app.launch()
        let map = app.otherElements["mainMap"]
        XCTAssertEqual(app.buttons["resumeFollowing"].value as? String, "Active")
        let centered = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let value = map.value as? String,
                  let latitude = Double(value.split(separator: "|").first.map(String.init) ?? "") else { return false }
            return abs(latitude - 48.8566) < 0.001
        }, object: map)
        XCTAssertEqual(XCTWaiter.wait(for: [centered], timeout: 10), .completed)
        let components = try XCTUnwrap(map.value as? String).split(separator: "|")
        XCTAssertEqual(try XCTUnwrap(Double(components[1])), 2.3522, accuracy: 0.001)
    }

    @MainActor
    func testCyclistStaysFixedWhileFollowingAndMovesToMapWhenBrowsing() {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launchArguments = ["-ui-testing-route-preview", "-ui-testing-moving-location"]
        app.launch()
        XCTAssertTrue(app.buttons["startNavigation"].waitForExistence(timeout: 10))
        app.buttons["startNavigation"].tap()
        let cyclist = app.otherElements["fixedCyclist"]
        XCTAssertTrue(cyclist.waitForExistence(timeout: 3))
        let initialFrame = cyclist.frame
        let map = app.otherElements["mainMap"]
        XCTAssertEqual(initialFrame.midY, app.frame.minY + app.frame.height * 2 / 3, accuracy: 4)
        waitForDistanceChange(app.staticTexts["remainingDistance"])
        XCTAssertEqual(cyclist.frame.midX, initialFrame.midX, accuracy: 1)
        XCTAssertEqual(cyclist.frame.midY, initialFrame.midY, accuracy: 1)
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: map.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.5)))
        XCTAssertFalse(cyclist.exists)
        XCTAssertTrue(app.otherElements["geographicCyclist"].exists)
        app.buttons["resumeFollowing"].tap()
        XCTAssertTrue(cyclist.waitForExistence(timeout: 3))
        XCTAssertFalse(app.otherElements["geographicCyclist"].exists)
        app.buttons["stopNavigation"].tap()
        XCTAssertFalse(cyclist.exists)
    }

    @MainActor
    func testFollowArrowRestoresRenderedTravelHeadingAndTiltAfterMapRotation() throws {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launchArguments = ["-ui-testing-route-preview", "-ui-testing-camera", "-ui-testing-moving-location", "-ui-testing-travel-course", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()
        XCTAssertTrue(app.buttons["startNavigation"].waitForExistence(timeout: 10))
        app.buttons["startNavigation"].tap()
        let map = app.otherElements["mainMap"]
        let original = try renderedCameraAngles(map)
        XCTAssertEqual(original.heading, 120, accuracy: 1)
        XCTAssertEqual(original.pitch, 45, accuracy: 1)
        for _ in 0..<2 {
            map.rotate(.pi / 2, withVelocity: .pi / 2)
            XCTAssertGreaterThan(abs(try renderedCameraAngles(map).heading - original.heading), 10)
            app.buttons["resumeFollowing"].tap()
            waitForDistanceChange(app.staticTexts["remainingDistance"])
            let restored = try renderedCameraAngles(map)
            XCTAssertEqual(restored.heading, original.heading, accuracy: 1)
            XCTAssertEqual(restored.pitch, 45, accuracy: 1)
            XCTAssertEqual(app.buttons["resumeFollowing"].value as? String, "Active")
        }
    }

    @MainActor
    private func renderedCameraAngles(_ map: XCUIElement) throws -> (heading: Double, pitch: Double) {
        let components = try XCTUnwrap(map.value as? String).split(separator: "|")
        XCTAssertEqual(components.count, 2)
        guard components.count == 2 else { throw NSError(domain: "MissingCameraAngles", code: 1) }
        return (try XCTUnwrap(Double(components[0])), try XCTUnwrap(Double(components[1])))
    }

    @MainActor
    func testDraggingMapPausesFollowingUntilArrowIsPressed() {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launchArguments = ["-ui-testing-route-preview", "-ui-testing-moving-location"]
        app.launch()
        XCTAssertTrue(app.buttons["startNavigation"].waitForExistence(timeout: 10))
        app.buttons["startNavigation"].tap()
        let arrow = app.buttons["resumeFollowing"]
        XCTAssertTrue(arrow.waitForExistence(timeout: 3))
        XCTAssertEqual(arrow.value as? String, "Active")
        let remainingDistance = app.staticTexts["remainingDistance"]
        waitForDistanceChange(remainingDistance)
        XCTAssertEqual(arrow.value as? String, "Active")
        let map = app.otherElements["mainMap"]
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: map.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.5)))
        XCTAssertTrue(NSPredicate(format: "value == %@", "Paused").evaluate(with: arrow))
        waitForDistanceChange(remainingDistance)
        XCTAssertEqual(arrow.value as? String, "Paused")
        arrow.tap()
        XCTAssertEqual(arrow.value as? String, "Active")
        waitForDistanceChange(remainingDistance)
        XCTAssertEqual(arrow.value as? String, "Active")
        XCTAssertTrue(app.buttons["stopNavigation"].isHittable)
    }

    @MainActor
    private func waitForDistanceChange(_ distance: XCUIElement) {
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", distance.label), object: distance)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 4), .completed)
    }

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
            XCTAssertEqual(app.otherElements["fixedCyclist"].frame.midY, app.frame.minY + app.frame.height * 2 / 3, accuracy: 4)
            XCTAssertTrue(app.staticTexts["nextManeuver"].isHittable)
            XCTAssertTrue(app.staticTexts["remainingDistance"].isHittable)
            XCTAssertTrue(app.buttons["stopNavigation"].isHittable)
            XCTAssertLessThan(app.staticTexts["nextManeuver"].frame.maxX, app.frame.midX)
            XCTAssertLessThan(app.staticTexts["remainingDuration"].frame.maxX, app.frame.midX)
            XCTAssertLessThan(app.buttons["stopNavigation"].frame.maxX, app.frame.midX)
            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screenshot.name = "Navigation-\(orientation.rawValue)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.buttons["stopNavigation"].waitForExistence(timeout: 3))
        XCTAssertLessThan(app.staticTexts["nextManeuver"].frame.maxY, app.frame.midY)
        XCTAssertGreaterThan(app.staticTexts["remainingDuration"].frame.minY, app.frame.midY)
        XCTAssertEqual(app.otherElements["fixedCyclist"].frame.midY, app.frame.minY + app.frame.height * 2 / 3, accuracy: 4)
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
        XCTAssertEqual(app.buttons["startNavigation"].label, "Start")
        app.buttons["startNavigation"].tap()
        XCTAssertTrue(app.buttons["stopNavigation"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["stopNavigation"].label, "End")
        XCTAssertFalse(app.buttons["startNavigation"].exists)
        XCTAssertTrue(app.staticTexts["nextManeuver"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["nextManeuver"].label, "Turn left")
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
        let search = app.buttons["destinationSearch"]
        XCTAssertTrue(search.exists)
        search.tap()
        app.textFields["activeDestinationSearch"].typeText("Berlin")
        XCTAssertTrue(app.buttons["cancelSearch"].exists)
        app.buttons["cancelSearch"].tap()
        XCTAssertEqual(search.label, "Where to?")
    }
}
