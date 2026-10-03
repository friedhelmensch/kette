import XCTest
import MapKit
@testable import KETTE

final class RoutePreviewTests: XCTestCase {
    func testManeuverInstructionsAreEnglish() {
        let cases: [(ManeuverType, String)] = [
            (.straight, "Continue straight"), (.left, "Turn left"), (.right, "Turn right"),
            (.slightLeft, "Turn slightly left"), (.slightRight, "Turn slightly right"),
            (.sharpLeft, "Turn sharply left"), (.sharpRight, "Turn sharply right"),
            (.keepLeft, "Keep left"), (.keepRight, "Keep right"), (.uTurn, "Make a U-turn"),
            (.roundabout, "Continue around the roundabout"), (.destination, "Continue to your destination")
        ]
        for (type, expected) in cases {
            let maneuver = RouteManeuver(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0), type: type, distanceFromRouteStartMeters: 0)
            XCTAssertEqual(maneuver.instruction, expected)
        }
        let exit = RouteManeuver(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0), type: .roundabout, distanceFromRouteStartMeters: 0, roundaboutExit: 2)
        XCTAssertEqual(exit.instruction, "At the roundabout, take exit 2")
    }

    func testKilometersAndMinutesAreFormattedForGermanLocale() {
        let preview = RoutePreview(route: route(distance: 12_400, duration: 2_520), locale: Locale(identifier: "de_DE"))
        XCTAssertEqual(preview.distanceText, "12,4 km")
        XCTAssertEqual(preview.durationText, "42 min")
    }

    func testShortRouteUsesMetersAndRoundsDurationUp() {
        let preview = RoutePreview(route: route(distance: 550, duration: 61), locale: Locale(identifier: "de_DE"))
        XCTAssertEqual(preview.distanceText, "550 m")
        XCTAssertEqual(preview.durationText, "2 min")
    }

    func testCameraBoundsIncludeEntireRouteWithPadding() {
        let route = route(distance: 12_400, duration: 2_520)
        let preview = RoutePreview(route: route)
        let geometryBounds = MKPolyline(coordinates: route.coordinates, count: route.coordinates.count).boundingMapRect
        for coordinate in route.coordinates {
            XCTAssertTrue(preview.mapRect.contains(MKMapPoint(coordinate)))
        }
        XCTAssertGreaterThan(preview.mapRect.width, geometryBounds.width)
        XCTAssertGreaterThan(preview.mapRect.height, geometryBounds.height)
    }

    private func route(distance: Double, duration: Double) -> BicycleRoute {
        BicycleRoute(coordinates: [
            CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405),
            CLLocationCoordinate2D(latitude: 52.535, longitude: 13.42),
            CLLocationCoordinate2D(latitude: 52.509, longitude: 13.376)
        ], distanceMeters: distance, estimatedDurationSeconds: duration)
    }
}
