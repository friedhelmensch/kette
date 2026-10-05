import CoreLocation
import UIKit
import Observation

@MainActor
@Observable
final class MapViewModel {
    var query = "" {
        didSet {
            retrySearch()
        }
    }
    var isSearching = false
    private(set) var suggestions: [SearchSuggestion] = []
    private(set) var destination: Destination?
    private(set) var currentCoordinate: CLLocationCoordinate2D?
    private(set) var locationDenied = false
    private(set) var searchError: String?
    private(set) var isResolving = false

    private(set) var navigationCoordinate: CLLocationCoordinate2D?
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
        UIApplication.shared.isIdleTimerDisabled = true
        isFollowingPosition = true
        location.setNavigationActive(true)
        updateNavigationProgress()
    }

    func stopNavigation() {
        if isRerouting {
            cancelRoute()
        }
        isNavigating = false
        UIApplication.shared.isIdleTimerDisabled = false
        isFollowingPosition = false
        routeError = nil
        navigationEngine = nil
        navigationCoordinate = nil
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
    private var navigationEngine: NavigationEngine?
    private var routeTask: Task<Void, Never>?
    private var routeRequestID: UUID?
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
            beginRouteRequest()
        }
    }

    private func updateNavigationProgress() {
        guard let coordinate = currentCoordinate, let accuracy = location.horizontalAccuracy,
              let progress = navigationEngine?.progress(at: coordinate, horizontalAccuracy: accuracy) else { return }
        navigationCoordinate = coordinate
        navigationProgress = progress
        navigationHeadingDegrees = location.course ?? progress.routeHeadingDegrees
        offRouteFixes = progress.distanceFromRouteMeters > offRouteDistanceMeters ? offRouteFixes + 1 : 0
        guard offRouteFixes >= requiredOffRouteFixes, !isRouting, !isRerouting,
              lastRerouteTime.map({ now().timeIntervalSince($0) >= rerouteCooldownSeconds }) ?? true else { return }
        offRouteFixes = 0
        beginRouteRequest()
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
            cancelRoute()
            route = nil
            routeError = nil
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
        if let routeTask {
            await routeTask.value
            return
        }
        guard let task = beginRouteRequest() else { return }
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    @discardableResult
    private func beginRouteRequest() -> Task<Void, Never>? {
        guard !isRouting, let start = currentCoordinate, let destination else { return nil }
        let requestID = UUID()
        routeRequestID = requestID
        isRouting = true
        isRerouting = isNavigating
        if isNavigating { lastRerouteTime = now() }
        routeError = nil
        let task = Task { [self] in
            defer {
                if routeRequestID == requestID {
                    routeTask = nil
                    routeRequestID = nil
                    isRouting = false
                    isRerouting = false
                }
            }
            do {
                let result = try await routing.calculateRoute(from: start, to: destination.coordinate)
                try Task.checkCancellation()
                guard routeRequestID == requestID else { return }
                route = result
                if isNavigating {
                    navigationEngine = NavigationEngine(route: result)
                    offRouteFixes = 0
                    updateNavigationProgress()
                }
            } catch {
                guard routeRequestID == requestID, !Task.isCancelled, !(error is CancellationError) else { return }
                routeError = error as? RoutingError == .noRoute
                    ? "No bicycle route found."
                    : "Could not calculate route."
            }
        }
        routeTask = task
        return task
    }

    private func cancelRoute() {
        routeTask?.cancel()
        routeTask = nil
        routeRequestID = nil
        isRouting = false
        isRerouting = false
    }

    func retrySearch() {
        cancelResolution()
        suggestions = []
        searchError = nil
        search.updateQuery(query.trimmingCharacters(in: .whitespacesAndNewlines))
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
