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
    private(set) var navigationHeadingDegrees: Double?
    private(set) var isNavigating = false
    private(set) var isFollowingPosition = true

    func pauseFollowingPosition() { isFollowingPosition = false }
    func resumeFollowingPosition() { isFollowingPosition = true }
    private(set) var isRerouting = false

    func startNavigation() {
        guard let route, currentCoordinate != nil, !locationDenied, !isRouting else { return }
        navigationEngine = NavigationEngine(route: route)
        offRouteFixes = 0
        lastRerouteTime = nil
        cancelSearch()
        isNavigating = true
        isFollowingPosition = true
        location.setNavigationActive(true)
        updateNavigationProgress()
    }

    func stopNavigation() {
        if isRerouting {
            rerouteTask?.cancel()
            routeTask?.cancel()
            rerouteTask = nil
            isRouting = false
            isRerouting = false
        }
        isNavigating = false
        isFollowingPosition = false
        routeError = nil
        navigationEngine = nil
        navigationProgress = nil
        navigationHeadingDegrees = nil
        location.setNavigationActive(false)
        offRouteFixes = 0
    }

    private(set) var route: BicycleRoute?
    private(set) var isRouting = false
    private(set) var routeError: String?

    private let location: any LocationProviding
    private let search: any DestinationSearching
    private let routing: any RoutingService
    private let now: () -> Date
    private let offRouteDistanceMeters = 30.0
    private let requiredOffRouteFixes = 3
    private let rerouteCooldownSeconds = 20.0
    private var offRouteFixes = 0
    private var lastRerouteTime: Date?
    private var rerouteTask: Task<Void, Never>?
    private var navigationEngine: NavigationEngine?
    private var routeTask: Task<BicycleRoute, Error>?
    private var requestedPermission = false
    private var updatingLocation = false
    private var selectionID = UUID()

    init(location: any LocationProviding, search: any DestinationSearching, routing: any RoutingService = BRouterService(), now: @escaping () -> Date = Date.init) {
        self.location = location
        self.search = search
        self.routing = routing
        self.now = now
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
        navigationHeadingDegrees = location.course ?? progress.routeHeadingDegrees
        offRouteFixes = progress.distanceFromRouteMeters > offRouteDistanceMeters ? offRouteFixes + 1 : 0
        guard offRouteFixes >= requiredOffRouteFixes, !isRouting, !isRerouting,
              lastRerouteTime.map({ now().timeIntervalSince($0) >= rerouteCooldownSeconds }) ?? true else { return }
        offRouteFixes = 0
        lastRerouteTime = now()
        isRerouting = true
        rerouteTask = Task { [weak self] in
            guard let self, !Task.isCancelled else { return }
            await calculateRoute()
            guard !Task.isCancelled else { return }
            isRerouting = false
            rerouteTask = nil
        }
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
                searchError = "Could not load destination. Please try again."
            }
        }
        if selectionID == requestID { isResolving = false }
    }

    func calculateRoute() async {
        guard !isRouting, let start = currentCoordinate, let destination else { return }
        if isNavigating {
            isRerouting = true
            lastRerouteTime = now()
        }
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
            if isNavigating {
                navigationEngine = NavigationEngine(route: result)
                offRouteFixes = 0
                updateNavigationProgress()
            }
        } catch {
            guard !task.isCancelled else { return }
            if !(error is CancellationError) {
                routeError = error as? RoutingError == .noRoute
                    ? "No bicycle route found."
                    : "Could not calculate route."
            }
        }
        isRouting = false
        isRerouting = false
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
