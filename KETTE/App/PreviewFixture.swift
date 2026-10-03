#if DEBUG
import CoreLocation

// Fixed services for the preview UI test; no GPS permission or network access.
@MainActor
enum PreviewFixture {
    static func makeModel() -> MapViewModel {
        let model = MapViewModel(
            location: FixtureLocationService(),
            search: FixtureSearchService(),
            routing: FixtureRoutingService()
        )
        model.start()
        Task {
            await model.select(SearchSuggestion(id: "preview", title: "Potsdamer Platz", subtitle: "Berlin"))
        }
        return model
    }
}

@MainActor
private final class FixtureLocationService: LocationProviding {
    let authorization = CLAuthorizationStatus.authorizedWhenInUse
    let horizontalAccuracy: Double? = 5
    let coordinate: CLLocationCoordinate2D? = CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405)
    var onChange: (() -> Void)?
    func requestPermission() {}
    func startUpdates() {}
    func setNavigationActive(_ active: Bool) {}
}

@MainActor
private final class FixtureSearchService: DestinationSearching {
    let suggestions: [SearchSuggestion] = []
    let errorMessage: String? = nil
    var onChange: (() -> Void)?
    func updateQuery(_ query: String) {}
    func cancel() {}
    func resolve(_ suggestion: SearchSuggestion) async throws -> Destination {
        Destination(name: suggestion.title, subtitle: suggestion.subtitle, latitude: 52.509, longitude: 13.376)
    }
}

@MainActor
private struct FixtureRoutingService: RoutingService {
    func calculateRoute(from start: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> BicycleRoute {
        let coordinates = [start, CLLocationCoordinate2D(latitude: 52.535, longitude: 13.42), destination]
        let geometry = RouteGeometry(coordinates: coordinates)
        return BicycleRoute(coordinates: coordinates, distanceMeters: 12_400, estimatedDurationSeconds: 2_520, maneuvers: [
            RouteManeuver(coordinate: coordinates[1], type: .left, distanceFromRouteStartMeters: geometry.cumulativeDistances[1]),
            RouteManeuver(coordinate: destination, type: .destination, distanceFromRouteStartMeters: geometry.totalDistance)
        ])
    }
}
#endif
