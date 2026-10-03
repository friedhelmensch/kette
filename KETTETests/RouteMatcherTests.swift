import XCTest
import CoreLocation
@testable import KETTE

final class RouteMatcherTests: XCTestCase {
    private let route = [
        CLLocationCoordinate2D(latitude: 0, longitude: 0),
        CLLocationCoordinate2D(latitude: 0, longitude: 0.001),
        CLLocationCoordinate2D(latitude: 0.001, longitude: 0.001)
    ]

    func testPointOnRoute() throws {
        let match = try XCTUnwrap(RouteMatcher(geometry: RouteGeometry(coordinates: route)).match(route[0]))
        XCTAssertEqual(match.distanceFromRouteMeters, 0, accuracy: 0.01)
        XCTAssertEqual(match.traveledDistanceMeters, 0, accuracy: 0.01)
    }

    func testProjectsOntoSegmentMidpointInsteadOfNearestVertex() throws {
        let location = CLLocationCoordinate2D(latitude: 0, longitude: 0.0005)
        let match = try XCTUnwrap(RouteMatcher(geometry: RouteGeometry(coordinates: route)).match(location))
        XCTAssertEqual(match.coordinate.longitude, 0.0005, accuracy: 0.0000001)
        XCTAssertEqual(match.segmentIndex, 0)
        XCTAssertEqual(match.distanceFromRouteMeters, 0, accuracy: 0.01)
        XCTAssertEqual(match.traveledDistanceMeters, 55.6, accuracy: 0.1)
    }

    func testPointBesideRoute() throws {
        let location = CLLocationCoordinate2D(latitude: 0.0001, longitude: 0.0005)
        let match = try XCTUnwrap(RouteMatcher(geometry: RouteGeometry(coordinates: route)).match(location))
        XCTAssertEqual(match.coordinate.latitude, 0, accuracy: 0.0000001)
        XCTAssertEqual(match.coordinate.longitude, 0.0005, accuracy: 0.0000001)
        XCTAssertEqual(match.distanceFromRouteMeters, 11.12, accuracy: 0.1)
    }

    func testProjectionClampsToEndpoint() throws {
        let location = CLLocationCoordinate2D(latitude: 0, longitude: -0.0003)
        let match = try XCTUnwrap(RouteMatcher(geometry: RouteGeometry(coordinates: route)).match(location))
        XCTAssertEqual(match.coordinate.longitude, 0, accuracy: 0.0000001)
        XCTAssertEqual(match.traveledDistanceMeters, 0, accuracy: 0.01)
        XCTAssertEqual(match.distanceFromRouteMeters, 33.36, accuracy: 0.1)
    }

    func testLongRouteFindsCorrectSegment() throws {
        let coordinates = (0...1_000).map { CLLocationCoordinate2D(latitude: 0, longitude: Double($0) * 0.00001) }
        let match = try XCTUnwrap(RouteMatcher(geometry: RouteGeometry(coordinates: coordinates)).match(
            CLLocationCoordinate2D(latitude: 0, longitude: 0.005555)
        ))
        XCTAssertEqual(match.segmentIndex, 555)
        XCTAssertEqual(match.traveledDistanceMeters, 617.69, accuracy: 0.1)
    }
}
