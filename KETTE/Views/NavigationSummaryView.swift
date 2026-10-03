import SwiftUI

struct NavigationSummaryView: View {
    let progress: RouteProgress
    let stop: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(RoutePreview.durationText(seconds: progress.remainingDurationSeconds))
                    .font(.headline)
                    .accessibilityIdentifier("remainingDuration")
                Text(RoutePreview.distanceText(meters: progress.remainingDistanceMeters))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("remainingDistance")
            }
            .monospacedDigit()
            Spacer()
            Button("Beenden", action: stop)
                .accessibilityIdentifier("stopNavigation")
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding()
    }
}
