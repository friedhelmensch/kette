import XCTest
import CoreLocation
@testable import KETTE

@MainActor
final class BRouterServiceTests: XCTestCase {
    func testRequestAndGeoJSONConversion() async throws {
        var sentRequest: URLRequest?
        let service = BRouterService { request in
            sentRequest = request
            return self.response(self.fixture)
        }
        let route = try await service.calculateRoute(from: start, to: end)
        let request = try XCTUnwrap(sentRequest)
        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "brouter.de")
        XCTAssertEqual(components.path, "/brouter")
        XCTAssertEqual(query["lonlats"], "13.405,52.52|13.376,52.509")
        XCTAssertEqual(query["profile"], "trekking")
        XCTAssertEqual(query["format"], "geojson")
        XCTAssertEqual(query["timode"], "1")
        XCTAssertEqual(request.timeoutInterval, 30)
        XCTAssertEqual(route.coordinates.count, 2)
        XCTAssertEqual(route.coordinates.first?.latitude, 52.52)
        XCTAssertEqual(route.coordinates.first?.longitude, 13.405)
        XCTAssertEqual(route.distanceMeters, 3_000)
        XCTAssertEqual(route.estimatedDurationSeconds, 600)
    }

    func testMissingDurationUsesFifteenKilometersPerHour() async throws {
        let fixture = fixture.replacingOccurrences(of: ",\"total-time\":\"600\"", with: "")
        let service = BRouterService { _ in self.response(fixture) }
        let route = try await service.calculateRoute(from: start, to: end)
        XCTAssertEqual(route.estimatedDurationSeconds, 720, accuracy: 0.01)
    }

    func testHTTPFailureIsExplicit() async {
        let service = BRouterService { _ in self.response("unavailable", status: 503) }
        do {
            _ = try await service.calculateRoute(from: start, to: end)
            XCTFail("Expected an HTTP error")
        } catch {
            XCTAssertEqual(error as? RoutingError, .httpStatus(503))
        }
    }

    func testEmptyFeatureCollectionIsNoRoute() async {
        let service = BRouterService { _ in self.response("{\"type\":\"FeatureCollection\",\"features\":[]}") }
        do {
            _ = try await service.calculateRoute(from: start, to: end)
            XCTFail("Expected no route")
        } catch {
            XCTAssertEqual(error as? RoutingError, .noRoute)
        }
    }

    func testMalformedGeoJSONIsTypedError() async {
        let service = BRouterService { _ in self.response("not JSON") }
        do {
            _ = try await service.calculateRoute(from: start, to: end)
            XCTFail("Expected invalid response")
        } catch {
            XCTAssertEqual(error as? RoutingError, .invalidResponse)
        }
    }

    func testMalformedCoordinateIsRejected() async {
        let fixture = fixture.replacingOccurrences(of: "[13.405,52.52,34]", with: "[13.405]")
        let service = BRouterService { _ in self.response(fixture) }
        do {
            _ = try await service.calculateRoute(from: start, to: end)
            XCTFail("Expected invalid response")
        } catch {
            XCTAssertEqual(error as? RoutingError, .invalidResponse)
        }
    }

    func testCancellationPropagates() async {
        let service = BRouterService { _ in throw CancellationError() }
        do {
            _ = try await service.calculateRoute(from: start, to: end)
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testTurnHintsBecomeManeuversAtRouteIndices() async throws {
        let fixture = fixture.replacingOccurrences(of: "\"total-time\":\"600\"", with: "\"total-time\":\"600\",\"voicehints\":[[0,2,0,20,-90],[1,13,3,0,90]]")
        let service = BRouterService { _ in self.response(fixture) }
        let route = try await service.calculateRoute(from: start, to: end)
        XCTAssertEqual(route.maneuvers.map(\.type), [.left, .roundabout, .destination])
        XCTAssertEqual(route.maneuvers.first?.coordinate.latitude, start.latitude)
        XCTAssertEqual(route.maneuvers.first?.distanceFromRouteStartMeters, 0)
        let roundabout = try XCTUnwrap(route.maneuvers.first { $0.type == .roundabout })
        XCTAssertEqual(roundabout.roundaboutExit, 3)
        XCTAssertGreaterThan(roundabout.distanceFromRouteStartMeters, 0)
    }

    func testRouteWithoutHintsStillHasDestinationManeuver() async throws {
        let service = BRouterService { _ in self.response(self.fixture) }
        let route = try await service.calculateRoute(from: start, to: end)
        XCTAssertEqual(route.maneuvers.map(\.type), [.destination])
    }

    func testInvalidManeuverIndexIsRejected() async {
        let fixture = fixture.replacingOccurrences(of: "\"total-time\":\"600\"", with: "\"total-time\":\"600\",\"voicehints\":[[99,2,0,20,-90]]")
        let service = BRouterService { _ in self.response(fixture) }
        do {
            _ = try await service.calculateRoute(from: start, to: end)
            XCTFail("Expected invalid response")
        } catch {
            XCTAssertEqual(error as? RoutingError, .invalidResponse)
        }
    }

    private let start = CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405)
    private let end = CLLocationCoordinate2D(latitude: 52.509, longitude: 13.376)
    private let fixture = """
    {"type":"FeatureCollection","features":[{"type":"Feature",
    "properties":{"track-length":"3000","total-time":"600"},
    "geometry":{"type":"LineString","coordinates":[[13.405,52.52,34],[13.376,52.509,33]]}}]}
    """

    private func response(_ json: String, status: Int = 200) -> (Data, URLResponse) {
        (Data(json.utf8), HTTPURLResponse(
            url: URL(string: "https://brouter.de/brouter")!,
            statusCode: status, httpVersion: nil, headerFields: nil
        )!)
    }
}
