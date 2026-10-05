import CoreLocation

struct RouteMatch {
    let coordinate: CLLocationCoordinate2D
    let segmentIndex: Int
    let distanceFromRouteMeters: Double
    let traveledDistanceMeters: Double
}

struct RouteMatcher {
    let geometry: RouteGeometry

    /// Projects onto each segment in a local meter-based plane and returns the nearest point.
    func match(_ coordinate: CLLocationCoordinate2D, previousTraveledDistanceMeters: Double? = nil) -> RouteMatch? {
        var nearest: RouteMatch?
        let latitudeScale = RouteGeometry.earthRadiusMeters * .pi / 180
        for index in geometry.coordinates.indices.dropLast() {
            let start = geometry.coordinates[index]
            let end = geometry.coordinates[index + 1]
            let longitudeScale = latitudeScale * cos((start.latitude + end.latitude) / 2 * .pi / 180)
            let dx = (end.longitude - start.longitude) * longitudeScale
            let dy = (end.latitude - start.latitude) * latitudeScale
            let px = (coordinate.longitude - start.longitude) * longitudeScale
            let py = (coordinate.latitude - start.latitude) * latitudeScale
            let squaredLength = dx * dx + dy * dy
            let fraction = squaredLength > 0 ? min(1, max(0, (px * dx + py * dy) / squaredLength)) : 0
            let distance = hypot(px - fraction * dx, py - fraction * dy)
            let segmentLength = geometry.cumulativeDistances[index + 1] - geometry.cumulativeDistances[index]
            let traveled = geometry.cumulativeDistances[index] + fraction * segmentLength
            let isCloser = distance < (nearest?.distanceFromRouteMeters ?? .infinity)
            var preferContinuity = false
            if let previous = previousTraveledDistanceMeters, let nearest,
               abs(distance - nearest.distanceFromRouteMeters) < 1 {
                // At overlapping segments, stay near the last progress and prefer the forward leg on a tie.
                let candidateDelta = traveled - previous
                let nearestDelta = nearest.traveledDistanceMeters - previous
                preferContinuity = abs(candidateDelta) < abs(nearestDelta)
                    || (abs(abs(candidateDelta) - abs(nearestDelta)) < 0.01 && candidateDelta > nearestDelta)
                if !preferContinuity { continue }
            }
            if isCloser || preferContinuity {
                nearest = RouteMatch(
                    coordinate: CLLocationCoordinate2D(
                        latitude: start.latitude + fraction * (end.latitude - start.latitude),
                        longitude: start.longitude + fraction * (end.longitude - start.longitude)
                    ),
                    segmentIndex: index,
                    distanceFromRouteMeters: distance,
                    traveledDistanceMeters: geometry.cumulativeDistances[index] + fraction * segmentLength
                )
            }
        }
        return nearest
    }
}
