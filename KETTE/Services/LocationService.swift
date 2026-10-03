import CoreLocation

@MainActor
final class LocationService: NSObject, LocationProviding, @preconcurrency CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var previousLocation: CLLocation?
    private(set) var coordinate: CLLocationCoordinate2D?
    private(set) var horizontalAccuracy: Double?
    private(set) var course: Double?
    var onChange: (() -> Void)?
    var authorization: CLAuthorizationStatus { manager.authorizationStatus }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10
    }

    func requestPermission() { manager.requestWhenInUseAuthorization() }
    func startUpdates() { manager.startUpdatingLocation() }

    func setNavigationActive(_ active: Bool) {
        manager.desiredAccuracy = active ? kCLLocationAccuracyBest : kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = active ? 5 : 10
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            manager.stopUpdatingLocation()
            coordinate = nil
            horizontalAccuracy = nil
            course = nil
            previousLocation = nil
        }
        onChange?()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last, latest.horizontalAccuracy >= 0 else { return }
        coordinate = latest.coordinate
        horizontalAccuracy = latest.horizontalAccuracy
        course = latest.course >= 0 && latest.speed >= 1 ? latest.course : nil
        if course == nil, latest.horizontalAccuracy <= 50,
           let previousLocation, previousLocation.horizontalAccuracy <= 50,
           latest.distance(from: previousLocation) >= 5 {
            course = RouteGeometry.bearing(from: previousLocation.coordinate, to: latest.coordinate)
        }
        previousLocation = latest
        onChange?()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Core Location retries temporary location-unavailable errors automatically.
        onChange?()
    }
}
