struct RouteProgress {
    let distanceFromRouteMeters: Double
    let traveledDistanceMeters: Double
    let remainingDistanceMeters: Double
    let fractionCompleted: Double
    let nextManeuver: RouteManeuver?
    let distanceToNextManeuverMeters: Double?
    let remainingDurationSeconds: Double
    let routeHeadingDegrees: Double
}
