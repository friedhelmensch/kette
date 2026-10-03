import XCTest
import UIKit
import CoreLocation
import MapKit
@testable import KETTE

@MainActor
final class MapNavigationTests: XCTestCase {
    func testNavigationKeepsScreenAwakeUntilStopped() async {
        let original = UIApplication.shared.isIdleTimerDisabled
        defer { UIApplication.shared.isIdleTimerDisabled = original }
        UIApplication.shared.isIdleTimerDisabled = false
        let (model, _, _) = await makeModel()
        XCTAssertFalse(UIApplication.shared.isIdleTimerDisabled)
        model.startNavigation()
        XCTAssertTrue(UIApplication.shared.isIdleTimerDisabled)
        model.pauseFollowingPosition()
        XCTAssertTrue(UIApplication.shared.isIdleTimerDisabled)
        model.stopNavigation()
        XCTAssertFalse(UIApplication.shared.isIdleTimerDisabled)
    }

    func testResumingUsesLatestGPSDirectionOfTravelAndFallsBackWhenUnavailable() async throws {
        let (model, location, _) = await makeModel()
        location.course = 135
        model.startNavigation()
        XCTAssertEqual(try XCTUnwrap(model.navigationHeadingDegrees), 135, accuracy: 0.1)
        model.pauseFollowingPosition()
        location.course = 230
        location.onChange?()
        model.resumeFollowingPosition()
        let heading = try XCTUnwrap(model.navigationHeadingDegrees)
        XCTAssertEqual(heading, 230, accuracy: 0.1)
        let camera = try XCTUnwrap(MainMapView.navigationCamera(at: location.coordinate!, heading: heading).camera)
        XCTAssertEqual(camera.heading, 230, accuracy: 0.1)
        location.course = nil
        location.onChange?()
        XCTAssertEqual(try XCTUnwrap(model.navigationHeadingDegrees), 90, accuracy: 0.1)
    }

    func testLocationServiceReportsValidMovingCourseAndIgnoresUnavailableCourse() {
        let service = LocationService()
        let manager = CLLocationManager()
        func update(course: Double, speed: Double) {
            service.locationManager(manager, didUpdateLocations: [CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405),
                altitude: 0, horizontalAccuracy: 5, verticalAccuracy: 5,
                course: course, speed: speed, timestamp: Date()
            )])
        }
        update(course: 135, speed: 4)
        XCTAssertEqual(service.course, 135)
        update(course: -1, speed: 4)
        XCTAssertNil(service.course)
        update(course: 135, speed: 0)
        XCTAssertNil(service.course)
    }

    func testLocationServiceDerivesTravelDirectionWhenGPSSuppliesOnlyPositions() throws {
        let service = LocationService()
        let manager = CLLocationManager()
        for longitude in [13.405, 13.407] {
            service.locationManager(manager, didUpdateLocations: [CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: 52.52, longitude: longitude),
                altitude: 0, horizontalAccuracy: 5, verticalAccuracy: 5,
                course: -1, speed: -1, timestamp: Date()
            )])
        }
        XCTAssertEqual(try XCTUnwrap(service.course), 90, accuracy: 0.1)
    }

    func testManualMapMovementPausesFollowingWhileGPSProgressContinues() async throws {
        let (model, location, _) = await makeModel()
        model.startNavigation()
        XCTAssertTrue(model.isFollowingPosition)
        let initialDistance = try XCTUnwrap(model.navigationProgress).remainingDistanceMeters
        model.pauseFollowingPosition()
        location.coordinate = CLLocationCoordinate2D(latitude: 0.0005, longitude: 0.001)
        location.onChange?()
        XCTAssertFalse(model.isFollowingPosition)
        XCTAssertTrue(model.isNavigating)
        XCTAssertLessThan(try XCTUnwrap(model.navigationProgress).remainingDistanceMeters, initialDistance)
        model.resumeFollowingPosition()
        XCTAssertTrue(model.isFollowingPosition)
    }

    func testConfirmedDeviationReplacesRouteAndKeepsNavigationActive() async throws {
        let (model, location, routing) = await makeModel()
        let originalID = model.route?.id
        model.startNavigation()
        routing.result = BicycleRoute(coordinates: [offRouteCoordinate, destinationCoordinate], distanceMeters: 350, estimatedDurationSeconds: 180)
        sendOffRouteUpdates(3, location: location)
        await settleTasks()
        XCTAssertEqual(routing.starts.count, 2)
        XCTAssertEqual(routing.starts.last?.longitude, offRouteCoordinate.longitude)
        XCTAssertEqual(routing.destinations.last?.latitude, destinationCoordinate.latitude)
        XCTAssertNotEqual(model.route?.id, originalID)
        XCTAssertTrue(model.isNavigating)
        XCTAssertEqual(try XCTUnwrap(model.navigationProgress).remainingDistanceMeters, 350, accuracy: 0.1)
        XCTAssertNil(model.navigationProgress?.nextManeuver)
    }

    func testOneDeviationOrPoorAccuracyDoesNotRerouteAndReturningResetsCount() async {
        let (model, location, routing) = await makeModel()
        model.startNavigation()
        sendOffRouteUpdates(1, location: location)
        location.horizontalAccuracy = 200
        sendOffRouteUpdates(4, location: location)
        await settleTasks()
        XCTAssertEqual(routing.starts.count, 1)
        location.horizontalAccuracy = 5
        location.coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0.0005)
        location.onChange?()
        sendOffRouteUpdates(2, location: location)
        await settleTasks()
        XCTAssertEqual(routing.starts.count, 1)
    }

    func testPendingRerouteDoesNotStartDuplicateRequestsAndStopDiscardsResponse() async {
        let (model, location, routing) = await makeModel()
        let originalID = model.route?.id
        var resume: CheckedContinuation<Void, Never>?
        routing.beforeResponse = { await withCheckedContinuation { resume = $0 } }
        model.startNavigation()
        sendOffRouteUpdates(3, location: location)
        await settleTasks()
        XCTAssertEqual(routing.starts.count, 2)
        XCTAssertTrue(model.isRouting)
        sendOffRouteUpdates(5, location: location)
        await settleTasks()
        XCTAssertEqual(routing.starts.count, 2)
        model.stopNavigation()
        resume?.resume()
        await settleTasks()
        XCTAssertFalse(model.isRouting)
        XCTAssertFalse(model.isNavigating)
        XCTAssertEqual(model.route?.id, originalID)
        XCTAssertNil(model.navigationProgress)
    }

    func testFailedRerouteKeepsOldRouteAndCooldownAllowsLaterRetry() async {
        var time = Date(timeIntervalSince1970: 1_000)
        let (model, location, routing) = await makeModel(now: { time })
        let originalID = model.route?.id
        model.startNavigation()
        routing.error = .httpStatus(503)
        sendOffRouteUpdates(3, location: location)
        await settleTasks()
        XCTAssertEqual(routing.starts.count, 2)
        XCTAssertEqual(model.route?.id, originalID)
        XCTAssertTrue(model.isNavigating)
        XCTAssertNotNil(model.routeError)
        sendOffRouteUpdates(3, location: location)
        await settleTasks()
        XCTAssertEqual(routing.starts.count, 2)
        time = time.addingTimeInterval(21)
        routing.error = nil
        routing.result = BicycleRoute(coordinates: [offRouteCoordinate, destinationCoordinate], distanceMeters: 350, estimatedDurationSeconds: 180)
        sendOffRouteUpdates(3, location: location)
        await settleTasks()
        XCTAssertEqual(routing.starts.count, 3)
        XCTAssertNotEqual(model.route?.id, originalID)
        XCTAssertNil(model.routeError)
    }

    func testStoppingAfterFailedRerouteReturnsToExistingPreview() async {
        let (model, location, routing) = await makeModel()
        let originalID = model.route?.id
        model.startNavigation()
        routing.error = .httpStatus(503)
        sendOffRouteUpdates(3, location: location)
        await settleTasks()
        XCTAssertNotNil(model.routeError)
        model.stopNavigation()
        XCTAssertFalse(model.isNavigating)
        XCTAssertEqual(model.route?.id, originalID)
        XCTAssertNil(model.routeError)
    }

    private let offRouteCoordinate = CLLocationCoordinate2D(latitude: 0.0005, longitude: -0.001)
    private let destinationCoordinate = CLLocationCoordinate2D(latitude: 0.001, longitude: 0.001)

    private func sendOffRouteUpdates(_ count: Int, location: FakeLocationService) {
        location.coordinate = offRouteCoordinate
        for _ in 0..<count { location.onChange?() }
    }

    private func settleTasks() async {
        for _ in 0..<30 { await Task.yield() }
    }

    func testNavigationCameraIsTiltedAndPointsAlongRoute() throws {
        let coordinate = CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405)
        let camera = try XCTUnwrap(MainMapView.navigationCamera(at: coordinate, heading: 90).camera)
        XCTAssertEqual(camera.centerCoordinate.latitude, coordinate.latitude, accuracy: 0.000001)
        XCTAssertEqual(camera.centerCoordinate.longitude, coordinate.longitude, accuracy: 0.000001)
        XCTAssertEqual(camera.heading, 90, accuracy: 0.1)
        XCTAssertEqual(camera.pitch, 45, accuracy: 0.1)
        XCTAssertEqual(camera.distance, 300, accuracy: 1)
    }

    func testGPSUpdatesReduceRemainingDistanceAndAdvanceManeuver() async throws {
        let (model, location, _) = await makeModel()
        model.startNavigation()
        let initial = try XCTUnwrap(model.navigationProgress)
        XCTAssertEqual(initial.nextManeuver?.type, .left)
        location.coordinate = CLLocationCoordinate2D(latitude: 0.0005, longitude: 0.001)
        location.onChange?()
        let updated = try XCTUnwrap(model.navigationProgress)
        XCTAssertLessThan(updated.remainingDistanceMeters, initial.remainingDistanceMeters)
        XCTAssertEqual(updated.nextManeuver?.type, .destination)
    }

    func testPoorGPSAccuracyDoesNotChangeProgress() async throws {
        let (model, location, _) = await makeModel()
        model.startNavigation()
        let initial = try XCTUnwrap(model.navigationProgress)
        location.horizontalAccuracy = 200
        location.coordinate = CLLocationCoordinate2D(latitude: 0.001, longitude: 0.001)
        location.onChange?()
        XCTAssertEqual(model.navigationProgress?.remainingDistanceMeters, initial.remainingDistanceMeters)
    }

    func testStoppingClearsProgressAndFurtherGPSUpdatesDoNotNavigate() async {
        let (model, location, _) = await makeModel()
        model.startNavigation()
        model.stopNavigation()
        location.coordinate = CLLocationCoordinate2D(latitude: 0.001, longitude: 0.001)
        location.onChange?()
        XCTAssertNil(model.navigationProgress)
        XCTAssertFalse(model.isNavigating)
    }

    private func makeModel(now: @escaping () -> Date = Date.init) async -> (MapViewModel, FakeLocationService, FakeRoutingService) {
        let coordinates = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0, longitude: 0.001),
            CLLocationCoordinate2D(latitude: 0.001, longitude: 0.001)
        ]
        let geometry = RouteGeometry(coordinates: coordinates)
        let location = FakeLocationService()
        location.authorization = .authorizedWhenInUse
        location.coordinate = coordinates[0]
        location.horizontalAccuracy = 5
        let search = FakeSearchService()
        search.destination = Destination(name: "Ziel", subtitle: nil, latitude: 0.001, longitude: 0.001)
        let routing = FakeRoutingService()
        routing.result = BicycleRoute(coordinates: coordinates, distanceMeters: 222.4, estimatedDurationSeconds: 120, maneuvers: [
            RouteManeuver(coordinate: coordinates[1], type: .left, distanceFromRouteStartMeters: geometry.cumulativeDistances[1]),
            RouteManeuver(coordinate: coordinates[2], type: .destination, distanceFromRouteStartMeters: geometry.totalDistance)
        ])
        let model = MapViewModel(location: location, search: search, routing: routing, now: now)
        model.start()
        await model.select(SearchSuggestion(id: "target", title: "Ziel", subtitle: ""))
        return (model, location, routing)
    }
}
