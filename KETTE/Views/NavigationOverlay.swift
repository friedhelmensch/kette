import SwiftUI

struct NavigationOverlay: View {
    let progress: RouteProgress

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: progress.nextManeuver?.symbol ?? "arrow.up")
                .font(.largeTitle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                if let distance = progress.distanceToNextManeuverMeters {
                    Text(distance <= 10 ? "Now" : "In \(RoutePreview.distanceText(meters: distance))")
                        .font(.title3.weight(.semibold))
                        .accessibilityIdentifier("maneuverDistance")
                }
                Text(progress.nextManeuver?.instruction ?? "Follow the route")
                    .font(.headline)
                    .accessibilityIdentifier("nextManeuver")
            }
            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}
