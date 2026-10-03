import CoreLocation

struct NavigationEngine {
    private let matcher: RouteMatcher
    private let calculator: RouteProgressCalculator
    private let maximumHorizontalAccuracyMeters = 50.0

    init(route: BicycleRoute) {
        let geometry = RouteGeometry(coordinates: route.coordinates)
        matcher = RouteMatcher(geometry: geometry)
        calculator = RouteProgressCalculator(route: route, geometry: geometry)
    }

    func progress(at coordinate: CLLocationCoordinate2D, horizontalAccuracy: Double) -> RouteProgress? {
        guard horizontalAccuracy >= 0, horizontalAccuracy <= maximumHorizontalAccuracyMeters,
              CLLocationCoordinate2DIsValid(coordinate), let match = matcher.match(coordinate) else { return nil }
        return calculator.calculate(match: match)
    }
}
