# KETTE

Minimal native bicycle navigation for iPhone, built with SwiftUI and Apple frameworks.
Targets iOS 27+ and Swift 6. Supports portrait and both landscape orientations.
No third-party dependencies.

## Open and run

Open `KETTE.xcodeproj` in Xcode, select the shared **KETTE** scheme and an iPhone
simulator running iOS 27, then Run. For a physical iPhone, select your own signing
team and set a unique bundle identifier in the app target's Signing & Capabilities.
The current `de.kette.KETTE` identifier is a development placeholder.

## Development

Follow `AGENTS.md`: write a failing test before implementing each behavior.
Unit tests use injected location, search, and routing services. UI tests exercise
the native map/search controls and the preview's Start/Beenden flow. A Debug-only
fixed route fixture makes the preview UI test independent of GPS and networking;
normal launches use the live services. Live Apple search needs internet access.

Run tests with Product → Test in Xcode, or:

```sh
xcodebuild test -project KETTE.xcodeproj -scheme KETTE \
  -destination 'platform=iOS Simulator,name=iPhone 13 mini' \
  CODE_SIGNING_ALLOWED=NO
```

The implementation plan is in `IMPLEMENTATION_PLAN_BikeNav.md` (historical filename).
Milestones 1–5 cover map/location, destination search, bicycle routing, route
preview, and basic foreground navigation. Start follows the cyclist and shows the
next maneuver, distance to it, remaining distance, and estimated remaining time.
Beenden returns to the preview. Voice, rerouting, background navigation, and
arrival handling follow in later increments.

Navigation projects GPS coordinates onto route segments and caches cumulative
geometry distances once per route. It scales remaining distance and time by the
fraction of route geometry completed. GPS fixes with horizontal accuracy worse
than 50 meters leave the previous progress intact. BRouter turn hints supply
maneuvers and roundabout exits; street names are not included in these hints.

Routing uses the public prototype endpoint `https://brouter.de/brouter` with the
`trekking` profile. Selecting a destination sends the starting and destination
coordinates to that endpoint. No location history is stored. The endpoint can be
changed through `BRouterService`'s initializer; use owned infrastructure before
public release. Tests inject responses rather than calling the public server.

## Manual integration checks

- On fresh installation, grant location access while using the app and verify the
  blue user-location marker. In Simulator, choose Features → Location to supply GPS.
- Deny permission and verify the explanation and Settings action. Grant permission
  in Settings and return to the app; verify location updates resume.
- Search for a place, select an Apple suggestion, and verify the destination marker.
- With a simulated location selected in Xcode, choose Potsdamer Platz and verify
  a blue bicycle route appears and the camera fits the full route. Check the bottom
  preview's distance and estimated duration. Tap Start to follow your position,
  then Beenden to return to the complete route preview.
- To simulate movement, run the app, select Potsdamer Platz and tap Start. Choose
  `Berlin-Testfahrt` from Xcode's Debug → Simulate Location menu. The fixed ride in
  `Fixtures/Berlin-Testfahrt.gpx` pauses for 30 seconds, then follows a public Berlin
  sample route for about eight minutes. Check that turn distances and remaining
  totals change. The selected Apple destination may differ slightly from the
  fixture endpoint. Stop manually with Beenden when finished.
- Cancel a search and retry. Check search failures with networking disabled.

No background location permission or location history is used in this increment.
