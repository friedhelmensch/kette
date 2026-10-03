import CoreLocation

struct Destination: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let subtitle: String?
    let latitude: Double
    let longitude: Double
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct SearchSuggestion: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
}
