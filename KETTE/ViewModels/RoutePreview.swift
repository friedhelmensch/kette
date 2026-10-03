import MapKit

struct RoutePreview {
    let route: BicycleRoute
    var locale: Locale = .current

    var distanceText: String { Self.distanceText(meters: route.distanceMeters, locale: locale) }

    static func distanceText(meters: Double, locale: Locale = .current) -> String {
        if meters < 1_000 {
            return "\(Int(meters.rounded())) m"
        }
        let kilometers = (meters / 1_000).formatted(
            .number.precision(.fractionLength(1)).locale(locale)
        )
        return "\(kilometers) km"
    }

    var durationText: String { Self.durationText(seconds: max(1, route.estimatedDurationSeconds)) }

    static func durationText(seconds: Double) -> String {
        "\(max(0, Int(ceil(seconds / 60)))) min"
    }

    var mapRect: MKMapRect {
        let bounds = MKPolyline(coordinates: route.coordinates, count: route.coordinates.count).boundingMapRect
        return bounds.insetBy(dx: -max(bounds.width * 0.15, 200), dy: -max(bounds.height * 0.15, 200))
    }
}
