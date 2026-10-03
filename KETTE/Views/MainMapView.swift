import SwiftUI
import MapKit

struct MainMapView: View {
    static func navigationCamera(at coordinate: CLLocationCoordinate2D, heading: Double) -> MapCameraPosition {
        .camera(MapCamera(centerCoordinate: coordinate, distance: 300, heading: heading, pitch: 45))
    }

    @Bindable var model: MapViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Namespace private var mapScope
    @State private var renderedCameraAngles = ""
    @State private var camera: MapCameraPosition = .userLocation(
        followsHeading: false,
        fallback: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405),
            latitudinalMeters: 5_000,
            longitudinalMeters: 5_000
        ))
    )

    var body: some View {
        GeometryReader { geometry in
            let landscapeNavigation = model.isNavigating && geometry.size.width > geometry.size.height
            Map(position: $camera, scope: mapScope) {
                UserAnnotation()
                if let route = model.route {
                    MapPolyline(coordinates: route.coordinates)
                        .stroke(.blue, lineWidth: 6)
                }
                if let destination = model.destination {
                    Marker(destination.name, coordinate: destination.coordinate)
                        .tint(.orange)
                }
            }
            .accessibilityIdentifier("mainMap")
            .accessibilityValue(renderedCameraAngles, isEnabled: !renderedCameraAngles.isEmpty)
            .onMapCameraChange(frequency: .onEnd) { context in
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-ui-testing-camera") {
                    renderedCameraAngles = "\(context.camera.heading)|\(context.camera.pitch)"
                }
                #endif
            }
            .mapControls { }
            .overlay(alignment: .topTrailing) {
                VStack(spacing: 8) {
                    Button {
                        model.resumeFollowingPosition()
                        if model.isNavigating {
                            updateNavigationCamera(animated: false)
                        } else {
                            camera = .userLocation(followsHeading: false, fallback: .automatic)
                        }
                    } label: {
                        Image(systemName: model.isFollowingPosition ? "location.fill" : "location")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .background(.regularMaterial, in: Circle())
                    }
                    .accessibilityLabel("Position folgen")
                    .accessibilityValue(model.isFollowingPosition ? "Aktiv" : "Pausiert")
                    .accessibilityIdentifier("resumeFollowing")
                    MapCompass(scope: mapScope)
                }
                .padding(12)
            }
            .safeAreaInset(edge: .leading, spacing: 0) {
                if landscapeNavigation {
                    VStack(spacing: 0) {
                        topPanel
                        Spacer(minLength: 8)
                        bottomPanel
                    }
                    .frame(width: 280)
                    .frame(maxHeight: .infinity)
                }
            }
            .safeAreaInset(edge: .top) {
                if !landscapeNavigation { topPanel }
            }
            .safeAreaInset(edge: .bottom) {
                if !landscapeNavigation { bottomPanel }
            }
            .task { model.start() }
            .onChange(of: camera.positionedByUser) { _, positionedByUser in
                if positionedByUser { model.pauseFollowingPosition() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { model.start() }
            }
            .onChange(of: model.route?.id) { _, _ in
                if model.isNavigating {
                    updateNavigationCamera()
                } else if let route = model.route {
                    model.pauseFollowingPosition()
                    camera = .rect(RoutePreview(route: route).mapRect)
                }
            }
            .onChange(of: model.isNavigating) { _, navigating in
                if navigating {
                    updateNavigationCamera()
                } else if let route = model.route {
                    camera = .rect(RoutePreview(route: route).mapRect)
                }
            }
            .onChange(of: [model.navigationProgress?.traveledDistanceMeters, model.navigationHeadingDegrees]) { _, _ in
                if model.isNavigating { updateNavigationCamera() }
            }
            .onChange(of: model.destination) { _, destination in
                guard let destination else { return }
                model.pauseFollowingPosition()
                camera = .region(MKCoordinateRegion(
                    center: destination.coordinate,
                    latitudinalMeters: 1_500,
                    longitudinalMeters: 1_500
                ))
            }
        }
    }

    @ViewBuilder
    private var topPanel: some View {
        if model.isNavigating {
            if let progress = model.navigationProgress {
                NavigationOverlay(progress: progress)
                    .padding(.horizontal)
                    .padding(.top, 8)
            } else {
                Text("Standort wird ermittelt …")
                    .padding()
                    .background(.regularMaterial, in: Capsule())
            }
        } else {
            DestinationSearchView(model: model)
                .padding(.horizontal)
                .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var bottomPanel: some View {
        if model.locationDenied {
            VStack(spacing: 8) {
                Text("Erlaube den Standortzugriff, um deine Position auf der Karte zu sehen.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                Button("Einstellungen öffnen") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding()
        } else if model.isRouting {
            VStack(spacing: 8) {
                ProgressView(model.isRerouting ? "Route wird neu berechnet …" : "Route wird berechnet …")
                if model.isNavigating {
                    Button("Beenden", action: model.stopNavigation)
                        .accessibilityIdentifier("stopNavigation")
                }
            }
            .padding()
            .background(.regularMaterial, in: Capsule())
            .padding()
        } else if let error = model.routeError {
            VStack(spacing: 8) {
                Text(error)
                    .font(.subheadline)
                Button("Erneut versuchen") {
                    Task { await model.calculateRoute() }
                }
                if model.isNavigating {
                    Button("Beenden", action: model.stopNavigation)
                        .accessibilityIdentifier("stopNavigation")
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding()
        } else if model.isNavigating, let progress = model.navigationProgress {
            NavigationSummaryView(progress: progress, stop: model.stopNavigation)
        } else if model.isNavigating {
            HStack {
                Label("Navigation", systemImage: "location.fill")
                Spacer()
                Button("Beenden", action: model.stopNavigation)
                    .accessibilityIdentifier("stopNavigation")
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding()
        } else if let route = model.route, !model.isSearching {
            RoutePreviewCard(preview: RoutePreview(route: route), start: model.startNavigation)
        } else if model.currentCoordinate == nil {
            Label("Standort wird ermittelt …", systemImage: "location")
                .font(.subheadline)
                .padding()
                .background(.regularMaterial, in: Capsule())
                .padding()
        }
    }

    private func updateNavigationCamera(animated: Bool = true) {
        guard model.isFollowingPosition, let coordinate = model.currentCoordinate,
              let heading = model.navigationHeadingDegrees else { return }
        let position = Self.navigationCamera(at: coordinate, heading: heading)
        if animated {
            withAnimation(.linear(duration: 0.5)) { camera = position }
        } else {
            camera = position
        }
    }
}
