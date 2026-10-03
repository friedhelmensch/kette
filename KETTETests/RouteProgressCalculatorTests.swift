import XCTest
import CoreLocation
@testable import KETTE

final class RouteProgressCalculatorTests: XCTestCase {
    func testRouteHeadingPointsEastThenNorthAfterTurn() throws {
        XCTAssertEqual(try progress(at: coordinates[0]).routeHeadingDegrees, 90, accuracy: 0.1)
        XCTAssertEqual(try progress(at: CLLocationCoordinate2D(latitude: 0.0005, longitude: 0.001)).routeHeadingDegrees, 0, accuracy: 0.1)
    }

    func testStartOfRoute() throws {
        let progress = try progress(at: coordinates[0])
        XCTAssertEqual(progress.traveledDistanceMeters, 0, accuracy: 0.01)
        XCTAssertEqual(progress.remainingDistanceMeters, 222.4, accuracy: 0.01)
        XCTAssertEqual(progress.fractionCompleted, 0, accuracy: 0.001)
        XCTAssertEqual(progress.nextManeuver?.type, .left)
        XCTAssertEqual(try XCTUnwrap(progress.distanceToNextManeuverMeters), 111.2, accuracy: 0.1)
    }

    func testMiddleOfRoute() throws {
        let progress = try progress(at: coordinates[1])
        XCTAssertEqual(progress.fractionCompleted, 0.5, accuracy: 0.001)
        XCTAssertEqual(progress.remainingDistanceMeters, 111.2, accuracy: 0.1)
        XCTAssertEqual(progress.remainingDurationSeconds, 60, accuracy: 0.1)
        XCTAssertEqual(progress.nextManeuver?.type, .left)
        XCTAssertEqual(try XCTUnwrap(progress.distanceToNextManeuverMeters), 0, accuracy: 0.1)
    }

    func testPassingTurnSelectsDestination() throws {
        let progress = try progress(at: CLLocationCoordinate2D(latitude: 0.0005, longitude: 0.001))
        XCTAssertEqual(progress.nextManeuver?.type, .destination)
        XCTAssertEqual(progress.remainingDistanceMeters, 55.6, accuracy: 0.1)
    }

    func testEndOfRoute() throws {
        let progress = try progress(at: coordinates[2])
        XCTAssertEqual(progress.fractionCompleted, 1, accuracy: 0.001)
        XCTAssertEqual(progress.remainingDistanceMeters, 0, accuracy: 0.01)
        XCTAssertEqual(progress.remainingDurationSeconds, 0, accuracy: 0.01)
    }

    private let coordinates = [
        CLLocationCoordinate2D(latitude: 0, longitude: 0),
        CLLocationCoordinate2D(latitude: 0, longitude: 0.001),
        CLLocationCoordinate2D(latitude: 0.001, longitude: 0.001)
    ]

    private func progress(at coordinate: CLLocationCoordinate2D) throws -> RouteProgress {
        let geometry = RouteGeometry(coordinates: coordinates)
        let route = BicycleRoute(coordinates: coordinates, distanceMeters: 222.4, estimatedDurationSeconds: 120, maneuvers: [
            RouteManeuver(coordinate: coordinates[1], type: .left, distanceFromRouteStartMeters: geometry.cumulativeDistances[1]),
            RouteManeuver(coordinate: coordinates[2], type: .destination, distanceFromRouteStartMeters: geometry.totalDistance)
        ])
        let match = try XCTUnwrap(RouteMatcher(geometry: geometry).match(coordinate))
        return RouteProgressCalculator(route: route, geometry: geometry).calculate(match: match)
    }
}
