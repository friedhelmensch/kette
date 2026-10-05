import SwiftUI
import MapKit

struct MainMapView: View {
    static func navigationCamera(at coordinate: CLLocationCoordinate2D, heading: Double) -> MapCameraPosition {
        .camera(MapCamera(centerCoordinate: coordinate, distance: 240, heading: heading, pitch: 45))
    }

    @Bindable var model: MapViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Namespace private var mapScope
    @State private var renderedCameraAngles = ""
    @State private var camera: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405),
        latitudinalMeters: 5_000,
        longitudinalMeters: 5_000
    ))

    var body: some View {
        GeometryReader { geometry in
            let landscapeNavigation = model.isNavigating && geometry.size.width > geometry.size.height
            Map(position: $camera, scope: mapScope) {
                if !model.isNavigating {
                    UserAnnotation()
                } else if !model.isFollowingPosition, let coordinate = model.currentCoordinate {
                    Annotation("Your location", coordinate: coordinate, anchor: .center) {
                        cyclistMarker
                            .accessibilityIdentifier("geographicCyclist")
                    }
                    .annotationTitles(.hidden)
                }
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
                if ProcessInfo.processInfo.arguments.contains("-ui-testing-launch-location") || ProcessInfo.processInfo.arguments.contains("-ui-testing-position-camera") {
                    renderedCameraAngles = "\(context.camera.centerCoordinate.latitude)|\(context.camera.centerCoordinate.longitude)"
                }
                #endif
            }
            .mapControls { }
            .overlay {
                if model.isNavigating && model.isFollowingPosition {
                    GeometryReader { mapGeometry in
                        cyclistMarker
                            .accessibilityIdentifier("fixedCyclist")
                            .position(
                                x: mapGeometry.size.width / 2,
                                y: mapGeometry.size.height / 2
                            )
                    }
                    .allowsHitTesting(false)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if model.isNavigating && model.isFollowingPosition {
                    Color.clear.frame(height: geometry.size.height / 3 + geometry.safeAreaInsets.bottom)
                }
            }
            .overlay(alignment: .topTrailing) {
                VStack(spacing: 8) {
                    Button {
                        model.resumeFollowingPosition()
                        updateFollowingCamera(animated: false)
                    } label: {
                        Image(systemName: model.isFollowingPosition ? "location.fill" : "location")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .background(.regularMaterial, in: Circle())
                    }
                    .accessibilityLabel("Follow location")
                    .accessibilityValue(model.isFollowingPosition ? "Active" : "Paused")
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
            .fullScreenCover(isPresented: $model.isSearching) {
                DestinationSearchView(model: model)
            }
            .onChange(of: [model.currentCoordinate?.latitude, model.currentCoordinate?.longitude], initial: true) { _, _ in
                guard !model.isNavigating else { return }
                updateFollowingCamera(animated: false)
            }
            .onChange(of: camera.positionedByUser) { _, positionedByUser in
                if positionedByUser { model.pauseFollowingPosition() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { model.start() }
            }
            .onChange(of: model.route?.id) { _, _ in
                if model.isNavigating {
                    updateFollowingCamera()
                } else if let route = model.route {
                    model.pauseFollowingPosition()
                    camera = .rect(RoutePreview(route: route).mapRect)
                }
            }
            .onChange(of: model.isNavigating) { _, navigating in
                if navigating {
                    updateFollowingCamera()
                } else if let route = model.route {
                    camera = .rect(RoutePreview(route: route).mapRect)
                }
            }
            .onChange(of: [model.navigationCoordinate?.latitude, model.navigationCoordinate?.longitude, model.navigationHeadingDegrees]) { _, _ in
                if model.isNavigating { updateFollowingCamera() }
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
                Text("Finding your location …")
                    .padding()
                    .background(.regularMaterial, in: Capsule())
            }
        } else {
            Button { model.isSearching = true } label: {
                Label("Where to?", systemImage: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            }
            .accessibilityLabel("Where to?")
            .accessibilityIdentifier("destinationSearch")
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    private var cyclistMarker: some View {
        Circle()
            .fill(.blue)
            .frame(width: 18, height: 18)
            .overlay(Circle().stroke(.white, lineWidth: 3))
            .shadow(radius: 2)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Your location")
    }

    @ViewBuilder
    private var bottomPanel: some View {
        if model.locationDenied {
            VStack(spacing: 8) {
                Text("Allow location access to see your position on the map.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding()
        } else if model.isNavigating, let progress = model.navigationProgress {
            NavigationSummaryView(
                progress: progress,
                stop: model.stopNavigation,
                status: model.isRerouting ? "Recalculating route …" : model.routeError,
                retry: model.routeError == nil ? nil : { Task { await model.calculateRoute() } }
            )
        } else if model.isNavigating {
            HStack {
                Label("Navigation", systemImage: "location.fill")
                Spacer()
                Button("End", action: model.stopNavigation)
                    .accessibilityIdentifier("stopNavigation")
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding()
        } else if model.isRouting {
            VStack(spacing: 8) {
                ProgressView("Calculating route …")
            }
            .padding()
            .background(.regularMaterial, in: Capsule())
            .padding()
        } else if let error = model.routeError {
            VStack(spacing: 8) {
                Text(error)
                    .font(.subheadline)
                Button("Try again") {
                    Task { await model.calculateRoute() }
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding()
        } else if let route = model.route, !model.isSearching {
            RoutePreviewCard(preview: RoutePreview(route: route), start: model.startNavigation)
        } else if model.currentCoordinate == nil {
            Label("Finding your location …", systemImage: "location")
                .font(.subheadline)
                .padding()
                .background(.regularMaterial, in: Capsule())
                .padding()
        }
    }

    private func updateFollowingCamera(animated: Bool = true) {
        guard model.isFollowingPosition else { return }
        let position: MapCameraPosition
        if model.isNavigating {
            guard let coordinate = model.navigationCoordinate,
                  let heading = model.navigationHeadingDegrees else { return }
            position = Self.navigationCamera(at: coordinate, heading: heading)
        } else {
            guard let coordinate = model.currentCoordinate else { return }
            position = .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 1_000, longitudinalMeters: 1_000))
        }
        if animated {
            withAnimation(.linear(duration: 0.5)) { camera = position }
        } else {
            camera = position
        }
    }
}
