import CoreLocation

@MainActor
protocol LocationProviding: AnyObject {
    var authorization: CLAuthorizationStatus { get }
    var coordinate: CLLocationCoordinate2D? { get }
    var horizontalAccuracy: Double? { get }
    var onChange: (() -> Void)? { get set }
    func requestPermission()
    func startUpdates()
    func setNavigationActive(_ active: Bool)
}

@MainActor
protocol DestinationSearching: AnyObject {
    var suggestions: [SearchSuggestion] { get }
    var errorMessage: String? { get }
    var onChange: (() -> Void)? { get set }
    func updateQuery(_ query: String)
    func resolve(_ suggestion: SearchSuggestion) async throws -> Destination
    func cancel()
}
