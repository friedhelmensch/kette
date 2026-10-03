import CoreLocation

struct RouteGeometry {
    static let earthRadiusMeters = 6_371_000.0
    let coordinates: [CLLocationCoordinate2D]
    let cumulativeDistances: [Double]
    var totalDistance: Double { cumulativeDistances.last ?? 0 }

    static func bearing(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        let latitude = start.latitude * .pi / 180
        let endLatitude = end.latitude * .pi / 180
        let longitudeDifference = (end.longitude - start.longitude) * .pi / 180
        let angle = atan2(
            sin(longitudeDifference) * cos(endLatitude),
            cos(latitude) * sin(endLatitude) - sin(latitude) * cos(endLatitude) * cos(longitudeDifference)
        ) * 180 / .pi
        return (angle + 360).truncatingRemainder(dividingBy: 360)
    }

    init(coordinates: [CLLocationCoordinate2D]) {
        self.coordinates = coordinates
        var cumulative: [Double] = coordinates.isEmpty ? [] : [0]
        for (start, end) in zip(coordinates, coordinates.dropFirst()) {
            let latitudeDelta = (end.latitude - start.latitude) * .pi / 180
            let longitudeDelta = (end.longitude - start.longitude) * .pi / 180
            let a = pow(sin(latitudeDelta / 2), 2)
                + cos(start.latitude * .pi / 180) * cos(end.latitude * .pi / 180)
                * pow(sin(longitudeDelta / 2), 2)
            let distance = Self.earthRadiusMeters * 2 * atan2(sqrt(a), sqrt(max(0, 1 - a)))
            cumulative.append((cumulative.last ?? 0) + distance)
        }
        cumulativeDistances = cumulative
    }
}
