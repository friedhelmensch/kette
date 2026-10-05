import SwiftUI

struct NavigationSummaryView: View {
    let progress: RouteProgress
    let stop: () -> Void
    var status: String? = nil
    var retry: (() -> Void)? = nil

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
            Button("End", action: stop)
                .accessibilityIdentifier("stopNavigation")
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding()
        .overlay(alignment: .top) {
            if let status {
                HStack {
                    Text(status).font(.caption)
                    if let retry { Button("Try again", action: retry).font(.caption) }
                }
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .offset(y: -32)
            }
        }
    }
}
