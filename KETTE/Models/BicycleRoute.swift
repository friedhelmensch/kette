import CoreLocation

struct BicycleRoute: Identifiable, Sendable {
    let id = UUID()
    let coordinates: [CLLocationCoordinate2D]
    let distanceMeters: Double
    let estimatedDurationSeconds: Double
    var maneuvers: [RouteManeuver] = []
}
