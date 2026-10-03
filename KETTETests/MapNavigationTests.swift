import XCTest
import CoreLocation
@testable import KETTE

@MainActor
final class MapNavigationTests: XCTestCase {
    func testGPSUpdatesReduceRemainingDistanceAndAdvanceManeuver() async throws {
        let (model, location) = await makeModel()
        model.startNavigation()
        let initial = try XCTUnwrap(model.navigationProgress)
        XCTAssertEqual(initial.nextManeuver?.type, .left)
        location.coordinate = CLLocationCoordinate2D(latitude: 0.0005, longitude: 0.001)
        location.onChange?()
        let updated = try XCTUnwrap(model.navigationProgress)
        XCTAssertLessThan(updated.remainingDistanceMeters, initial.remainingDistanceMeters)
        XCTAssertEqual(updated.nextManeuver?.type, .destination)
    }

    func testPoorGPSAccuracyDoesNotChangeProgress() async throws {
        let (model, location) = await makeModel()
        model.startNavigation()
        let initial = try XCTUnwrap(model.navigationProgress)
        location.horizontalAccuracy = 200
        location.coordinate = CLLocationCoordinate2D(latitude: 0.001, longitude: 0.001)
        location.onChange?()
        XCTAssertEqual(model.navigationProgress?.remainingDistanceMeters, initial.remainingDistanceMeters)
    }

    func testStoppingClearsProgressAndFurtherGPSUpdatesDoNotNavigate() async {
        let (model, location) = await makeModel()
        model.startNavigation()
        model.stopNavigation()
        location.coordinate = CLLocationCoordinate2D(latitude: 0.001, longitude: 0.001)
        location.onChange?()
        XCTAssertNil(model.navigationProgress)
        XCTAssertFalse(model.isNavigating)
    }

    private func makeModel() async -> (MapViewModel, FakeLocationService) {
        let coordinates = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0, longitude: 0.001),
            CLLocationCoordinate2D(latitude: 0.001, longitude: 0.001)
        ]
        let geometry = RouteGeometry(coordinates: coordinates)
        let location = FakeLocationService()
        location.authorization = .authorizedWhenInUse
        location.coordinate = coordinates[0]
        location.horizontalAccuracy = 5
        let search = FakeSearchService()
        search.destination = Destination(name: "Ziel", subtitle: nil, latitude: 0.001, longitude: 0.001)
        let routing = FakeRoutingService()
        routing.result = BicycleRoute(coordinates: coordinates, distanceMeters: 222.4, estimatedDurationSeconds: 120, maneuvers: [
            RouteManeuver(coordinate: coordinates[1], type: .left, distanceFromRouteStartMeters: geometry.cumulativeDistances[1]),
            RouteManeuver(coordinate: coordinates[2], type: .destination, distanceFromRouteStartMeters: geometry.totalDistance)
        ])
        let model = MapViewModel(location: location, search: search, routing: routing)
        model.start()
        await model.select(SearchSuggestion(id: "target", title: "Ziel", subtitle: ""))
        return (model, location)
    }
}
