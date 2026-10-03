import CoreLocation

enum ManeuverType: Sendable {
    case straight, left, right, slightLeft, slightRight, sharpLeft, sharpRight
    case keepLeft, keepRight, uTurn, roundabout, destination
}

struct RouteManeuver: Sendable {
    let coordinate: CLLocationCoordinate2D
    let type: ManeuverType
    var streetName: String? = nil
    let distanceFromRouteStartMeters: Double
    var roundaboutExit: Int? = nil
}

extension RouteManeuver {
    var instruction: String {
        switch type {
        case .straight: "Geradeaus"
        case .left: "Links abbiegen"
        case .right: "Rechts abbiegen"
        case .slightLeft: "Leicht links abbiegen"
        case .slightRight: "Leicht rechts abbiegen"
        case .sharpLeft: "Scharf links abbiegen"
        case .sharpRight: "Scharf rechts abbiegen"
        case .keepLeft: "Links halten"
        case .keepRight: "Rechts halten"
        case .uTurn: "Wenden"
        case .roundabout:
            if let exit = roundaboutExit, exit > 0 {
                "Im Kreisverkehr die \(exit). Ausfahrt nehmen"
            } else {
                "Dem Kreisverkehr folgen"
            }
        case .destination: "Zum Ziel"
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
