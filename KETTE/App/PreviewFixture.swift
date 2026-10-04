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
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-launch-location") || ProcessInfo.processInfo.arguments.contains("-ui-testing-search") { return model }
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
    var course: Double? {
        ProcessInfo.processInfo.arguments.contains("-ui-testing-travel-course") ? 120 : nil
    }
    var coordinate: CLLocationCoordinate2D? = CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405)
    private var movementTask: Task<Void, Never>?
    var onChange: (() -> Void)?
    func requestPermission() {}
    func startUpdates() {
        guard ProcessInfo.processInfo.arguments.contains("-ui-testing-launch-location") else { return }
        coordinate = nil
        movementTask = Task {
            try? await Task.sleep(for: .seconds(2))
            coordinate = CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)
            onChange?()
        }
    }
    func setNavigationActive(_ active: Bool) {
        movementTask?.cancel()
        guard active, ProcessInfo.processInfo.arguments.contains("-ui-testing-moving-location") else { return }
        movementTask = Task {
            for step in 1...15 {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                coordinate = CLLocationCoordinate2D(latitude: 52.52 + Double(step) * 0.00015, longitude: 13.405 + Double(step) * 0.00015)
                onChange?()
            }
        }
    }
}

@MainActor
private final class FixtureSearchService: DestinationSearching {
    private(set) var suggestions: [SearchSuggestion] = []
    let errorMessage: String? = nil
    var onChange: (() -> Void)?
    func updateQuery(_ query: String) {
        guard ProcessInfo.processInfo.arguments.contains("-ui-testing-search") else { return }
        suggestions = query.isEmpty ? [] : [SearchSuggestion(id: "preview", title: "Potsdamer Platz", subtitle: "Berlin")]
        onChange?()
    }
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
