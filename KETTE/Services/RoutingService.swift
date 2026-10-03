import CoreLocation

@MainActor
protocol RoutingService {
    func calculateRoute(from start: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> BicycleRoute
}

enum RoutingError: Error, Equatable {
    case httpStatus(Int)
    case noRoute
    case invalidResponse
}
