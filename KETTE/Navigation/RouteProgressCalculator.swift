struct RouteProgressCalculator {
    let route: BicycleRoute
    let geometry: RouteGeometry

    func calculate(match: RouteMatch) -> RouteProgress {
        let fraction = geometry.totalDistance > 0
            ? min(1, max(0, match.traveledDistanceMeters / geometry.totalDistance)) : 0
        let nextManeuver = route.maneuvers.first {
            $0.distanceFromRouteStartMeters >= match.traveledDistanceMeters
        }
        // Scale provider totals by geometry progress so preview and navigation totals agree.
        return RouteProgress(
            distanceFromRouteMeters: match.distanceFromRouteMeters,
            traveledDistanceMeters: route.distanceMeters * fraction,
            remainingDistanceMeters: route.distanceMeters * (1 - fraction),
            fractionCompleted: fraction,
            nextManeuver: nextManeuver,
            distanceToNextManeuverMeters: nextManeuver.map {
                max(0, $0.distanceFromRouteStartMeters - match.traveledDistanceMeters)
            },
            remainingDurationSeconds: route.estimatedDurationSeconds * (1 - fraction)
        )
    }
}
