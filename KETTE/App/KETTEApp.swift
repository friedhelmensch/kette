import SwiftUI

@main
struct KETTEApp: App {
    @State private var model: MapViewModel

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-route-preview") || ProcessInfo.processInfo.arguments.contains("-ui-testing-launch-location") || ProcessInfo.processInfo.arguments.contains("-ui-testing-search") {
            _model = State(initialValue: PreviewFixture.makeModel())
            return
        }
        #endif
        _model = State(initialValue: MapViewModel(
            location: LocationService(),
            search: DestinationSearchService()
        ))
    }

    var body: some Scene {
        WindowGroup { MainMapView(model: model) }
    }
}
