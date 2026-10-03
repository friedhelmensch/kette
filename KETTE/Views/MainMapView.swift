import SwiftUI
import MapKit

struct MainMapView: View {
    @Bindable var model: MapViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var camera: MapCameraPosition = .userLocation(
        followsHeading: false,
        fallback: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405),
            latitudinalMeters: 5_000,
            longitudinalMeters: 5_000
        ))
    )

    var body: some View {
        Map(position: $camera) {
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
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .safeAreaInset(edge: .top) {
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
        .safeAreaInset(edge: .bottom) {
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
                ProgressView("Route wird berechnet …")
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
        .task { model.start() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.start() }
        }
        .onChange(of: model.route?.id) { _, _ in
            if let route = model.route {
                camera = .rect(RoutePreview(route: route).mapRect)
            }
        }
        .onChange(of: model.isNavigating) { _, navigating in
            if navigating {
                camera = .userLocation(followsHeading: false, fallback: .automatic)
            } else if let route = model.route {
                camera = .rect(RoutePreview(route: route).mapRect)
            }
        }
        .onChange(of: model.destination) { _, destination in
            guard let destination else { return }
            camera = .region(MKCoordinateRegion(
                center: destination.coordinate,
                latitudinalMeters: 1_500,
                longitudinalMeters: 1_500
            ))
        }
    }
}
