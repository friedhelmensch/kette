# KETTE

Minimal native bicycle navigation for iPhone, built with SwiftUI and Apple frameworks.
Targets iOS 26+ and Swift 6. Supports portrait and both landscape orientations.
During navigation, the map follows the cyclist with a 45° tilt and points in the
GPS direction of travel. If GPS supplies only positions, direction is calculated
from successive accurate fixes at least 5 meters apart. Without a travel direction,
the camera uses the current route segment's direction.
Landscape navigation places the maneuver and remaining time/distance panels on
the left to give the map more room; portrait uses the top and bottom.
Moving the map manually pauses camera following. The arrow button resumes the
navigation view; GPS progress and rerouting continue while browsing the map.
No third-party dependencies.

## Open and run

Open `KETTE.xcodeproj` in Xcode, select the shared **KETTE** scheme and an iPhone
simulator running iOS 26 or newer, then Run. For a physical iPhone, select your own signing
team and set a unique bundle identifier in the app target's Signing & Capabilities.
The current `de.kette.KETTE` identifier is a development placeholder.

## Development

Follow `AGENTS.md`: write a failing test before implementing each behavior.
Unit tests use injected location, search, and routing services. UI tests exercise
the native map/search controls and the preview's Start/End flow. A Debug-only
fixed route fixture makes the preview UI test independent of GPS and networking;
normal launches use the live services. Live Apple search needs internet access.

Run tests with Product → Test in Xcode, or:

```sh
xcodebuild test -project KETTE.xcodeproj -scheme KETTE \
  -destination 'platform=iOS Simulator,name=iPhone 13 mini' \
  CODE_SIGNING_ALLOWED=NO
```

The implementation plan is in [IMPLEMENTATION_PLAN_KETTE.md](IMPLEMENTATION_PLAN_KETTE.md).
Milestones 1–5 cover map/location, destination search, bicycle routing, route
preview, and basic foreground navigation. Start follows the cyclist and shows the
next maneuver, distance to it, remaining distance, and estimated remaining time.
End returns to the preview. Automatic rerouting is included. Voice, background
navigation, and arrival handling follow in later increments.

Navigation projects GPS coordinates onto route segments and caches cumulative
geometry distances once per route. It scales remaining distance and time by the
fraction of route geometry completed. GPS fixes with horizontal accuracy worse
than 50 meters leave the previous progress intact. BRouter turn hints supply
maneuvers and roundabout exits; street names are not included in these hints.

Three consecutive valid GPS fixes more than 30 meters from the route trigger a
new route from the current location to the same destination. Requests have a
20-second cooldown. Navigation keeps running while the route is recalculated;
a failed request preserves the previous route and can be retried.

Routing uses the public endpoint `https://brouter.de/brouter` with the
`trekking` profile. Selecting a destination sends the starting and destination
coordinates to that endpoint. Rerouting sends the updated starting coordinate and
the original destination. KETTE stores no location history locally. BRouter's
[privacy policy](https://brouter.de/privacypolicy.html) states that routing
coordinates and request metadata, including IP addresses, are logged for two
weeks, plus ten additional days in hosting-provider backups.

The first public release is planned to use this service directly, without a KETTE
backend. Confirm acceptable app usage and request volume with the maintainers
before release; no explicit quota or availability guarantee was found in the
official pages reviewed on 2026-10-03. The endpoint can be changed through
`BRouterService`'s initializer. Tests inject responses rather than calling the
public server.

## Manual integration checks

- On fresh installation, grant location access while using the app and verify the
  blue user-location marker. In Simulator, choose Features → Location to supply GPS.
- Deny permission and verify the explanation and Settings action. Grant permission
  in Settings and return to the app; verify location updates resume.
- Search for a place, select an Apple suggestion, and verify the destination marker.
- With a simulated location selected in Xcode, choose Potsdamer Platz and verify
  a blue bicycle route appears and the camera fits the full route. Check the bottom
  preview's distance and estimated duration. Tap Start to follow your position,
  then End to return to the complete route preview.
- To simulate movement, run the app, select Potsdamer Platz and tap Start. Choose
  `Berlin-Testfahrt` from Xcode's Debug → Simulate Location menu. The fixed ride in
  `Fixtures/Berlin-Testfahrt.gpx` pauses for 30 seconds, then follows a public Berlin
  sample route for about eight minutes. Check that turn distances and remaining
  totals change. The selected Apple destination may differ slightly from the
  fixture endpoint. Stop manually with End when finished.
- During navigation, verify the map is tilted and the route ahead points up in
  portrait and landscape. The camera direction updates after a turn.
- Follow a different simulated ride from the calculated route. After three valid
  off-route fixes, verify “Route wird neu berechnet …” appears, then the route and
  instructions change while navigation stays active. End also works while
  waiting for the new route. With networking disabled, the old route is retained.
- Cancel a search and retry. Check search failures with networking disabled.

No background location permission or location history is used in this increment.
