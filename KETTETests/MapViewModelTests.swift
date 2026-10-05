import XCTest
import CoreLocation
@testable import KETTE

@MainActor
final class MapViewModelTests: XCTestCase {
    func testLocationPermissionExplanationIsEnglish() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") as? String,
                       "KETTE needs your location to show your position on the map.")
    }

    func testAppCanBeInstalledOnIOS26() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "MinimumOSVersion") as? String, "26.0")
    }

    func testAppSupportsPortraitAndBothLandscapeOrientations() {
        let orientations = Bundle.main.object(forInfoDictionaryKey: "UISupportedInterfaceOrientations") as? [String] ?? []
        XCTAssertTrue(orientations.contains("UIInterfaceOrientationPortrait"))
        XCTAssertTrue(orientations.contains("UIInterfaceOrientationLandscapeLeft"))
        XCTAssertTrue(orientations.contains("UIInterfaceOrientationLandscapeRight"))
    }

    func testStartRequestsOnlyWhenInUsePermissionWhenUndetermined() {
        let location = FakeLocationService()
        let model = MapViewModel(location: location, search: FakeSearchService())
        model.start()
        model.start()
        XCTAssertEqual(location.permissionRequests, 1)
        XCTAssertEqual(location.startRequests, 0)
    }

    func testAuthorizedStartBeginsLocationUpdates() {
        let location = FakeLocationService()
        location.authorization = .authorizedWhenInUse
        let model = MapViewModel(location: location, search: FakeSearchService())
        model.start()
        XCTAssertEqual(location.startRequests, 1)
        XCTAssertEqual(location.permissionRequests, 0)
    }

    func testDeniedPermissionExposesSettingsAction() {
        let location = FakeLocationService()
        location.authorization = .denied
        let model = MapViewModel(location: location, search: FakeSearchService())
        model.start()
        XCTAssertTrue(model.locationDenied)
        XCTAssertEqual(location.permissionRequests, 0)
    }

    func testAuthorizationChangeStartsUpdatesAndLocationIsPublished() {
        let location = FakeLocationService()
        let model = MapViewModel(location: location, search: FakeSearchService())
        model.start()
        location.authorization = .authorizedWhenInUse
        location.onChange?()
        XCTAssertEqual(location.startRequests, 1)
        location.coordinate = CLLocationCoordinate2D(latitude: 52.5, longitude: 13.4)
        location.onChange?()
        XCTAssertEqual(model.currentCoordinate?.latitude, 52.5)
        XCTAssertEqual(location.startRequests, 1)
    }

    func testRetrySearchClearsErrorAndRequestsSameQueryAgain() {
        let search = FakeSearchService()
        let model = MapViewModel(location: FakeLocationService(), search: search)
        model.query = "Berlin"
        search.errorMessage = "Search failed."
        search.onChange?()
        model.retrySearch()
        XCTAssertEqual(search.queries, ["Berlin", "Berlin"])
        XCTAssertNil(model.searchError)
        XCTAssertTrue(model.suggestions.isEmpty)
    }

    func testQueryIsForwardedAndEmptyQueryClearsSuggestions() {
        let search = FakeSearchService()
        let model = MapViewModel(location: FakeLocationService(), search: search)
        model.query = "Berlin"
        XCTAssertEqual(search.queries, ["Berlin"])
        search.suggestions = [suggestion]
        search.onChange?()
        XCTAssertEqual(model.suggestions, [suggestion])
        model.query = " "
        XCTAssertTrue(model.suggestions.isEmpty)
        XCTAssertEqual(search.queries.last, "")
    }

    func testSelectionResolvesDestinationAndDismissesSearch() async {
        let search = FakeSearchService()
        search.destination = destination
        let model = MapViewModel(location: FakeLocationService(), search: search)
        model.isSearching = true
        await model.select(suggestion)
        XCTAssertEqual(model.destination, destination)
        XCTAssertFalse(model.isSearching)
        XCTAssertFalse(model.isResolving)
    }

    func testResolutionFailureKeepsSearchOpenAndAllowsRetry() async {
        let search = FakeSearchService()
        search.shouldFail = true
        let model = MapViewModel(location: FakeLocationService(), search: search)
        model.isSearching = true
        await model.select(suggestion)
        XCTAssertNil(model.destination)
        XCTAssertNotNil(model.searchError)
        XCTAssertTrue(model.isSearching)
        XCTAssertFalse(model.isResolving)
        search.shouldFail = false
        search.destination = destination
        await model.select(suggestion)
        XCTAssertEqual(model.destination, destination)
        XCTAssertNil(model.searchError)
    }

    func testCancelledResolutionDoesNotShowError() async {
        let search = FakeSearchService()
        search.cancellation = true
        let model = MapViewModel(location: FakeLocationService(), search: search)
        await model.select(suggestion)
        XCTAssertNil(model.searchError)
        XCTAssertNil(model.destination)
        XCTAssertFalse(model.isResolving)
    }

    private var suggestion: SearchSuggestion {
        SearchSuggestion(id: "station", title: "Hauptbahnhof", subtitle: "Berlin")
    }
    private let destination = Destination(
        name: "Hauptbahnhof", subtitle: "Berlin", latitude: 52.525, longitude: 13.369
    )
}

@MainActor
final class FakeLocationService: LocationProviding {
    var course: Double?
    var authorization: CLAuthorizationStatus = .notDetermined
    var coordinate: CLLocationCoordinate2D?
    var onChange: (() -> Void)?
    var horizontalAccuracy: Double? = 5
    var navigationActive = false
    func setNavigationActive(_ active: Bool) { navigationActive = active }
    var permissionRequests = 0
    var startRequests = 0
    func requestPermission() { permissionRequests += 1 }
    func startUpdates() { startRequests += 1 }
}

@MainActor
final class FakeSearchService: DestinationSearching {
    var suggestions: [SearchSuggestion] = []
    var errorMessage: String?
    var onChange: (() -> Void)?
    var queries: [String] = []
    var destination: Destination?
    var shouldFail = false
    var cancellation = false
    func updateQuery(_ query: String) { queries.append(query) }
    func resolve(_ suggestion: SearchSuggestion) async throws -> Destination {
        if cancellation { throw CancellationError() }
        if shouldFail { throw URLError(.notConnectedToInternet) }
        return destination!
    }
    func cancel() {}
}
