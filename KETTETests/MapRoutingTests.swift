import XCTest
import CoreLocation
@testable import KETTE

@MainActor
final class MapRoutingTests: XCTestCase {
    func testSelectingDestinationFetchesRouteFromCurrentLocation() async {
        let (model, routing) = makeModel()
        await model.select(suggestion)
        XCTAssertEqual(routing.starts.count, 1)
        XCTAssertEqual(routing.starts.first?.latitude, 52.52)
        XCTAssertEqual(routing.destinations.first?.longitude, 13.376)
        XCTAssertEqual(model.route?.distanceMeters, 3_000)
        XCTAssertFalse(model.isRouting)
        XCTAssertNil(model.routeError)
    }

    func testWithoutGPSKeepsDestinationButDoesNotRoute() async {
        let (model, routing) = makeModel(hasLocation: false)
        await model.select(suggestion)
        XCTAssertEqual(model.destination?.name, "Potsdamer Platz")
        XCTAssertTrue(routing.starts.isEmpty)
        XCTAssertNil(model.route)
        XCTAssertFalse(model.isRouting)
    }

    func testRoutingFailureIsRetryable() async {
        let (model, routing) = makeModel()
        routing.error = .httpStatus(503)
        await model.select(suggestion)
        XCTAssertNil(model.route)
        XCTAssertNotNil(model.routeError)
        XCTAssertFalse(model.isRouting)
        routing.error = nil
        await model.calculateRoute()
        XCTAssertEqual(routing.starts.count, 2)
        XCTAssertEqual(model.route?.distanceMeters, 3_000)
        XCTAssertNil(model.routeError)
    }

    func testNoRouteHasSpecificMessage() async {
        let (model, routing) = makeModel()
        routing.error = .noRoute
        await model.select(suggestion)
        XCTAssertEqual(model.routeError, "Keine Fahrradroute gefunden.")
    }

    func testStartRequiresACalculatedRoute() {
        let (model, _) = makeModel()
        model.startNavigation()
        XCTAssertFalse(model.isNavigating)
    }

    func testStartAndStopNavigationPreserveRoute() async {
        let location = FakeLocationService()
        let (model, _) = makeModel(location: location)
        await model.select(suggestion)
        model.startNavigation()
        XCTAssertTrue(model.isNavigating)
        XCTAssertTrue(location.navigationActive)
        XCTAssertEqual(model.route?.distanceMeters, 3_000)
        model.stopNavigation()
        XCTAssertFalse(model.isNavigating)
        XCTAssertFalse(location.navigationActive)
        XCTAssertEqual(model.route?.distanceMeters, 3_000)
    }

    private let suggestion = SearchSuggestion(id: "platz", title: "Potsdamer Platz", subtitle: "Berlin")

    private func makeModel(hasLocation: Bool = true, location: FakeLocationService = FakeLocationService()) -> (MapViewModel, FakeRoutingService) {
        location.authorization = .authorizedWhenInUse
        if hasLocation { location.coordinate = CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405) }
        let search = FakeSearchService()
        search.destination = Destination(name: "Potsdamer Platz", subtitle: "Berlin", latitude: 52.509, longitude: 13.376)
        let routing = FakeRoutingService()
        let model = MapViewModel(location: location, search: search, routing: routing)
        model.start()
        return (model, routing)
    }
}

@MainActor
final class FakeRoutingService: RoutingService {
    var starts: [CLLocationCoordinate2D] = []
    var destinations: [CLLocationCoordinate2D] = []
    var result: BicycleRoute?
    var error: RoutingError?
    var beforeResponse: (() async -> Void)?
    func calculateRoute(from start: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> BicycleRoute {
        starts.append(start)
        destinations.append(destination)
        await beforeResponse?()
        if let error { throw error }
        if let result { return result }
        return BicycleRoute(coordinates: [start, destination], distanceMeters: 3_000, estimatedDurationSeconds: 720)
    }
}
