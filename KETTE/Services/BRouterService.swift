import Foundation
import CoreLocation

@MainActor
final class BRouterService: RoutingService {
    private let baseURL: URL
    private let loadData: (URLRequest) async throws -> (Data, URLResponse)
    private let fallbackSpeedMetersPerSecond = 15.0 / 3.6

    init(
        baseURL: URL = URL(string: "https://brouter.de/brouter")!,
        loadData: @escaping (URLRequest) async throws -> (Data, URLResponse) = {
            try await URLSession.shared.data(for: $0)
        }
    ) {
        self.baseURL = baseURL
        self.loadData = loadData
    }

    func calculateRoute(from start: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> BicycleRoute {
        try Task.checkCancellation()
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "lonlats", value: "\(start.longitude),\(start.latitude)|\(destination.longitude),\(destination.latitude)"),
            URLQueryItem(name: "profile", value: "trekking"),
            URLQueryItem(name: "format", value: "geojson"),
            URLQueryItem(name: "timode", value: "1")
        ]
        guard let url = components?.url else { throw RoutingError.invalidResponse }
        let request = URLRequest(url: url, timeoutInterval: 30)
        let (data, response) = try await loadData(request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else { throw RoutingError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else { throw RoutingError.httpStatus(response.statusCode) }

        let collection: FeatureCollection
        do {
            collection = try JSONDecoder().decode(FeatureCollection.self, from: data)
        } catch {
            throw RoutingError.invalidResponse
        }
        guard collection.type == "FeatureCollection" else { throw RoutingError.invalidResponse }
        guard let feature = collection.features.first else { throw RoutingError.noRoute }
        guard feature.geometry.type == "LineString" else { throw RoutingError.invalidResponse }
        guard feature.geometry.coordinates.count >= 2 else { throw RoutingError.noRoute }
        let coordinates = try feature.geometry.coordinates.map { position in
            guard position.count >= 2 else { throw RoutingError.invalidResponse }
            let coordinate = CLLocationCoordinate2D(latitude: position[1], longitude: position[0])
            guard CLLocationCoordinate2DIsValid(coordinate) else { throw RoutingError.invalidResponse }
            return coordinate
        }
        guard let distance = Double(feature.properties.distance), distance.isFinite, distance >= 0 else {
            throw RoutingError.invalidResponse
        }
        let duration = feature.properties.duration.flatMap(Double.init)
        let geometry = RouteGeometry(coordinates: coordinates)
        var maneuvers: [RouteManeuver] = []
        for hint in feature.properties.voiceHints ?? [] {
            guard hint.count >= 2,
                  let index = Int(exactly: hint[0]), coordinates.indices.contains(index),
                  let command = Int(exactly: hint[1]) else { throw RoutingError.invalidResponse }
            guard let type = maneuverType(command: command) else { continue }
            let exit = hint.count > 2 ? Int(exactly: hint[2]) : nil
            maneuvers.append(RouteManeuver(
                coordinate: coordinates[index], type: type,
                distanceFromRouteStartMeters: geometry.cumulativeDistances[index],
                roundaboutExit: type == .roundabout ? exit.map { abs($0) } : nil
            ))
        }
        maneuvers.append(RouteManeuver(
            coordinate: coordinates[coordinates.count - 1], type: .destination,
            distanceFromRouteStartMeters: geometry.totalDistance
        ))
        return BicycleRoute(
            coordinates: coordinates,
            distanceMeters: distance,
            estimatedDurationSeconds: duration.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
                ?? distance / fallbackSpeedMetersPerSecond,
            maneuvers: maneuvers
        )
    }

    private func maneuverType(command: Int) -> ManeuverType? {
        switch command {
        case 1: .straight
        case 2: .left
        case 3: .slightLeft
        case 4: .sharpLeft
        case 5: .right
        case 6: .slightRight
        case 7: .sharpRight
        case 8, 17: .keepLeft
        case 9, 18: .keepRight
        case 10, 11, 15: .uTurn
        case 13, 14: .roundabout
        default: nil
        }
    }

    // BRouter encodes distance in meters and duration in seconds as strings.
    private struct FeatureCollection: Decodable {
        let type: String
        let features: [Feature]
    }
    private struct Feature: Decodable {
        let properties: Properties
        let geometry: Geometry
    }
    private struct Properties: Decodable {
        let distance: String
        let duration: String?
        let voiceHints: [[Double]]?
        enum CodingKeys: String, CodingKey {
            case distance = "track-length"
            case duration = "total-time"
            case voiceHints = "voicehints"
        }
    }
    private struct Geometry: Decodable {
        let type: String
        let coordinates: [[Double]]
    }
}
