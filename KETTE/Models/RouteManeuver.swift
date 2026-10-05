import CoreLocation

enum ManeuverType: Sendable {
    case straight, left, right, slightLeft, slightRight, sharpLeft, sharpRight
    case keepLeft, keepRight, uTurn, roundabout, destination
}

struct RouteManeuver: Sendable {
    let coordinate: CLLocationCoordinate2D
    let type: ManeuverType
    let distanceFromRouteStartMeters: Double
    var roundaboutExit: Int? = nil
}

extension RouteManeuver {
    var instruction: String {
        switch type {
        case .straight: "Continue straight"
        case .left: "Turn left"
        case .right: "Turn right"
        case .slightLeft: "Turn slightly left"
        case .slightRight: "Turn slightly right"
        case .sharpLeft: "Turn sharply left"
        case .sharpRight: "Turn sharply right"
        case .keepLeft: "Keep left"
        case .keepRight: "Keep right"
        case .uTurn: "Make a U-turn"
        case .roundabout:
            if let exit = roundaboutExit, exit > 0 {
                "At the roundabout, take exit \(exit)"
            } else {
                "Continue around the roundabout"
            }
        case .destination: "Continue to your destination"
        }
    }

    var symbol: String {
        switch type {
        case .straight: "arrow.up"
        case .left, .sharpLeft: "arrow.turn.up.left"
        case .right, .sharpRight: "arrow.turn.up.right"
        case .slightLeft, .keepLeft: "arrow.up.left"
        case .slightRight, .keepRight: "arrow.up.right"
        case .uTurn: "arrow.uturn.down"
        case .roundabout: "arrow.trianglehead.clockwise"
        case .destination: "flag.checkered"
        }
    }
}
