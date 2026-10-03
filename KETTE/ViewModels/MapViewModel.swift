import CoreLocation
import Observation

@MainActor
@Observable
final class MapViewModel {
    var query = "" {
        didSet {
            cancelResolution()
            suggestions = []
            searchError = nil
            search.updateQuery(query.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
    var isSearching = false
    private(set) var suggestions: [SearchSuggestion] = []
    private(set) var destination: Destination?
    private(set) var currentCoordinate: CLLocationCoordinate2D?
    private(set) var locationDenied = false
    private(set) var searchError: String?
    private(set) var isResolving = false

    private(set) var navigationProgress: RouteProgress?
    private(set) var isNavigating = false

    func startNavigation() {
        guard let route, currentCoordinate != nil, !locationDenied, !isRouting else { return }
        navigationEngine = NavigationEngine(route: route)
        cancelSearch()
        isNavigating = true
        location.setNavigationActive(true)
        updateNavigationProgress()
    }

    func stopNavigation() {
        isNavigating = false
        navigationEngine = nil
        navigationProgress = nil
        location.setNavigationActive(false)
    }

    private(set) var route: BicycleRoute?
    private(set) var isRouting = false
    private(set) var routeError: String?

    private let location: any LocationProviding
    private let search: any DestinationSearching
    private let routing: any RoutingService
    private var navigationEngine: NavigationEngine?
    private var routeTask: Task<BicycleRoute, Error>?
    private var requestedPermission = false
    private var updatingLocation = false
    private var selectionID = UUID()

    init(location: any LocationProviding, search: any DestinationSearching, routing: any RoutingService = BRouterService()) {
        self.location = location
        self.search = search
        self.routing = routing
        location.onChange = { [weak self] in self?.refreshLocation() }
        search.onChange = { [weak self] in
            guard let self else { return }
            suggestions = search.suggestions
            searchError = search.errorMessage
        }
    }

    func start() {
        refreshLocation()
        if location.authorization == .notDetermined, !requestedPermission {
            requestedPermission = true
            location.requestPermission()
        }
    }

    private func refreshLocation() {
        currentCoordinate = location.coordinate
        locationDenied = location.authorization == .denied || location.authorization == .restricted
        if locationDenied, isNavigating { stopNavigation() }
        if location.authorization == .authorizedWhenInUse || location.authorization == .authorizedAlways {
            if !updatingLocation {
                updatingLocation = true
                location.startUpdates()
            }
        } else {
            updatingLocation = false
        }
        if isNavigating { updateNavigationProgress() }
        if currentCoordinate != nil, destination != nil, route == nil, routeError == nil, !isRouting {
            Task { await calculateRoute() }
        }
    }

    private func updateNavigationProgress() {
        guard let coordinate = currentCoordinate, let accuracy = location.horizontalAccuracy,
              let progress = navigationEngine?.progress(at: coordinate, horizontalAccuracy: accuracy) else { return }
        navigationProgress = progress
    }

    func select(_ suggestion: SearchSuggestion) async {
        guard !isResolving else { return }
        isResolving = true
        searchError = nil
        let requestID = UUID()
        selectionID = requestID
        do {
            let result = try await search.resolve(suggestion)
            guard selectionID == requestID, !Task.isCancelled else { return }
            routeTask?.cancel()
            route = nil
            routeError = nil
            isRouting = false
            destination = result
            cancelSearch()
            await calculateRoute()
        } catch is CancellationError {
            // Cancelling or replacing a search is a normal interaction.
        } catch {
            if selectionID == requestID, !Task.isCancelled {
                searchError = "Ziel konnte nicht geladen werden. Bitte erneut versuchen."
            }
        }
        if selectionID == requestID { isResolving = false }
    }

    func calculateRoute() async {
        guard !isRouting, let start = currentCoordinate, let destination else { return }
        isRouting = true
        routeError = nil
        let task = Task { try await routing.calculateRoute(from: start, to: destination.coordinate) }
        routeTask = task
        do {
            let result = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
            guard !task.isCancelled else { return }
            route = result
        } catch {
            guard !task.isCancelled else { return }
            if !(error is CancellationError) {
                routeError = error as? RoutingError == .noRoute
                    ? "Keine Fahrradroute gefunden."
                    : "Route konnte nicht berechnet werden."
            }
        }
        isRouting = false
    }

    func cancelSearch() {
        isSearching = false
        query = ""
    }

    private func cancelResolution() {
        selectionID = UUID()
        isResolving = false
        search.cancel()
    }
}
