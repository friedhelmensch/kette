import SwiftUI

struct RoutePreviewCard: View {
    let preview: RoutePreview
    let start: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Text(preview.distanceText)
                    .accessibilityIdentifier("routeDistance")
                Text("·")
                    .accessibilityHidden(true)
                Text(preview.durationText)
                    .accessibilityIdentifier("routeDuration")
            }
            .font(.title3.weight(.semibold))
            .monospacedDigit()
            Button("Start", systemImage: "location.fill", action: start)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("startNavigation")
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding()
    }
}
