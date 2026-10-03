# KETTE – Implementation Plan for Codex

## 1. Product Goal

Build a minimal, native iOS bicycle navigation app.

The app should deliberately avoid the complexity of apps such as Bikemap, Komoot, or OsmAnd.

The complete user flow is:

1. Open the app.
2. See the current location on a map.
3. Search for a destination.
4. Calculate a bicycle route.
5. Show the complete route on the map.
6. Show distance and estimated duration.
7. Tap **Start**.
8. Navigate along the route with turn-by-turn instructions.
9. If the user leaves the route, calculate a new route automatically.
10. Finish navigation when the destination is reached.

No accounts, social features, purchases, tour collections, fitness tracking, achievements, or complex settings.

---

## 2. Target Platform

Primary target:

- iPhone
- Native iOS
- Swift
- SwiftUI
- iOS 26+
- Support portrait and both landscape orientations. Landscape is the user's preferred navigation orientation.
- In landscape navigation, place the next maneuver and remaining time/distance in a left-hand column, leaving the map clear on the right. In portrait, keep them at the top and bottom.

Use Apple frameworks wherever possible.

Core technologies:

- SwiftUI
- MapKit
- CoreLocation
- AVFoundation / AVSpeechSynthesizer
- URLSession
- Swift Concurrency (`async` / `await`)

Routing engine:

- BRouter

Map rendering:

- Apple MapKit

Destination search:

- MapKit `MKLocalSearchCompleter`
- `MKLocalSearch`

---

## 3. Architecture

Initial MVP architecture:

```text
iPhone App
│
├── SwiftUI
│
├── MapKit
│
├── CoreLocation
│
├── Navigation Engine
│
├── AVSpeechSynthesizer
│
└── URLSession
      │
      ▼
   BRouter HTTP API
```

Do NOT create a custom backend for the first version.

Use BRouter's public HTTP service directly for the first public release.
KETTE will not run its own backend or routing infrastructure.

Keep the existing `RoutingService` boundary so the endpoint or provider can be
changed if necessary, without rewriting the UI.

---

## 4. Important Design Principles

### Keep the app minimal

Only expose functionality required for navigation.

Avoid:

- login
- registration
- profiles
- favorites in MVP
- ride history
- GPX import/export
- social features
- premium features
- subscriptions
- cycling statistics
- fitness integration
- multiple configuration screens
- complicated routing settings

### Modular code

Do not put everything into `ContentView.swift`.

Use separate models, services, navigation logic, and views.

### Testable navigation logic

Route matching, progress calculation, off-route detection, and maneuver selection should not depend directly on SwiftUI.

They should live in pure Swift classes/structs and be unit-testable.

---

# 5. Suggested Project Structure

```text
KETTE/
│
├── App/
│   └── KETTEApp.swift
│
├── Models/
│   ├── Coordinate.swift
│   ├── Destination.swift
│   ├── BicycleRoute.swift
│   ├── RouteManeuver.swift
│   ├── RouteProgress.swift
│   └── NavigationState.swift
│
├── Services/
│   ├── LocationService.swift
│   ├── DestinationSearchService.swift
│   ├── RoutingService.swift
│   ├── BRouterService.swift
│   └── SpeechService.swift
│
├── Navigation/
│   ├── NavigationEngine.swift
│   ├── RouteMatcher.swift
│   ├── RouteProgressCalculator.swift
│   └── OffRouteDetector.swift
│
├── ViewModels/
│   ├── MapViewModel.swift
│   ├── RoutePreviewViewModel.swift
│   └── NavigationViewModel.swift
│
├── Views/
│   ├── MainMapView.swift
│   ├── DestinationSearchView.swift
│   ├── RoutePreviewCard.swift
│   ├── NavigationOverlay.swift
│   └── NavigationSummaryView.swift
│
└── Tests/
    ├── RouteMatcherTests.swift
    ├── RouteProgressCalculatorTests.swift
    └── OffRouteDetectorTests.swift
```

Use fewer files if appropriate, but preserve these architectural boundaries.

---

# 6. Core Data Models

## Destination

```swift
struct Destination: Identifiable, Equatable {
    let id: UUID
    let name: String
    let subtitle: String?
    let coordinate: CLLocationCoordinate2D
}
```

## BicycleRoute

Should contain:

```swift
struct BicycleRoute {
    let coordinates: [CLLocationCoordinate2D]
    let distanceMeters: Double
    let estimatedDurationSeconds: Double
    let maneuvers: [RouteManeuver]
}
```

## RouteManeuver

```swift
enum ManeuverType {
    case straight
    case left
    case right
    case slightLeft
    case slightRight
    case sharpLeft
    case sharpRight
    case roundabout
    case destination
}
```

```swift
struct RouteManeuver {
    let coordinate: CLLocationCoordinate2D
    let type: ManeuverType
    let streetName: String?
    let distanceFromRouteStartMeters: Double
}
```

## RouteProgress

```swift
struct RouteProgress {
    let distanceFromRouteMeters: Double
    let traveledDistanceMeters: Double
    let remainingDistanceMeters: Double
    let fractionCompleted: Double
    let nextManeuver: RouteManeuver?
}
```

---

# 7. Routing Abstraction

Create a protocol:

```swift
protocol RoutingService {
    func calculateRoute(
        from start: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> BicycleRoute
}
```

Initial implementation:

```swift
final class BRouterService: RoutingService
```

This is important because a future version may route through:

- a self-hosted BRouter server
- an ASP.NET backend
- another routing engine

without changing the rest of the app.

---

# 8. BRouter Integration

Use BRouter as the route calculation engine.

Conceptual request:

```text
/brouter
?lonlats=<startLon>,<startLat>|<targetLon>,<targetLat>
&profile=trekking
&format=geojson
&timode=1
```

Responsibilities of `BRouterService`:

1. Build the request URL.
2. Call the HTTP API with `URLSession`.
3. Decode GeoJSON.
4. Convert coordinates from:

```text
[longitude, latitude]
```

to:

```swift
CLLocationCoordinate2D(latitude: ..., longitude: ...)
```

5. Parse route metadata.
6. Parse turn instructions if available.
7. Produce a `BicycleRoute`.

Do not expose raw BRouter JSON outside `BRouterService`.

---

# 9. Location Service

Create:

```swift
@MainActor
final class LocationService: NSObject, ObservableObject
```

Responsibilities:

- request location permission
- receive location updates
- expose current location
- expose heading
- expose speed
- expose horizontal accuracy
- support navigation in background when navigation is active

Use:

```swift
CLLocationManager
```

Do not request background location permission immediately on first app launch.

Only request the permissions necessary for normal route planning first.

Background navigation permissions should be requested contextually when navigation functionality requires them.

---

# 10. Destination Search

Use Apple search.

Implement:

```swift
MKLocalSearchCompleter
```

for autocomplete.

When a suggestion is selected:

1. Resolve it using `MKLocalSearch`.
2. Obtain the coordinate.
3. Create a `Destination`.
4. Close search results.
5. Calculate a bicycle route.

The user should not need to manually enter a complete address.

---

# 11. Main Screen

The initial screen contains:

- full-screen Apple map
- user location
- search field at the top

Conceptual UI:

```text
┌──────────────────────────────┐
│ 🔎 Wohin?                    │
├──────────────────────────────┤
│                              │
│                              │
│           MAP                │
│                              │
│            ●                 │
│        current position      │
│                              │
└──────────────────────────────┘
```

Use a native, clean iOS appearance.

Avoid persistent toolbars and menus.

---

# 12. Route Preview

After a destination is selected:

1. Call `RoutingService`.
2. Draw the returned route using `MapPolyline`.
3. Adjust the camera so the complete route is visible.
4. Show destination marker.
5. Show a bottom route preview card.

Example:

```text
┌──────────────────────────────┐
│                              │
│          ROUTE               │
│                              │
├──────────────────────────────┤
│ 12.4 km · 42 min             │
│                              │
│          START               │
└──────────────────────────────┘
```

Only show:

- distance
- estimated duration
- Start button

Optionally allow Cancel/Back.

Do not add route configuration to this screen in the MVP.

---

# 13. Duration Estimation

If BRouter returns an estimated duration, use it.

If no duration is available, estimate using a configurable cycling speed.

Initial fallback:

```text
15 km/h
```

Keep fallback speed as a constant/configuration value, not hard-coded throughout the code.

---

# 14. Navigation Mode

When the user taps **Start**:

- start high-frequency location updates
- switch to navigation camera
- keep route visible
- show current route progress
- show next maneuver
- show remaining distance
- show remaining estimated time

Conceptual interface:

```text
┌──────────────────────────────┐
│ ↰ In 180 m                   │
│   links auf Talstraße        │
├──────────────────────────────┤
│                              │
│              ↑               │
│              │               │
│             🚴               │
│             ╲                │
│              ╲               │
│                              │
├──────────────────────────────┤
│ 37 min             10.8 km   │
└──────────────────────────────┘
```

---

# 15. Navigation Camera

During navigation:

- center the map near the cyclist
- orient the map approximately in movement/heading direction
- use an explicit MapKit camera with a 45° tilt, centered near the cyclist and oriented using GPS course while moving (at least 1 m/s), with the current route segment as fallback; update with GPS progress and course in portrait and landscape
- If GPS course is unavailable, derive travel direction from consecutive fixes at least 5 m apart, each with horizontal accuracy no worse than 50 m. The follow arrow restores this latest travel direction and tilt.
- use a slightly tilted or forward-looking camera if MapKit allows a clean implementation
- avoid constantly jumping or overreacting to noisy heading values
- After the user moves the map manually, keep the camera where they left it until the arrow button is pressed. Resume the navigation camera on that button; progress and rerouting continue while camera following is paused.

Do not make navigation camera logic tightly coupled to route matching.

---

# 16. Route Matching

Implement `RouteMatcher`.

Input:

- current GPS coordinate
- route polyline

Output:

- nearest position on the route
- distance from the route
- route segment index
- distance traveled along the route

Do NOT simply look for the closest route vertex.

Project the GPS point onto route segments and find the closest projection.

The implementation should be unit-tested.

---

# 17. Route Progress

Implement a `RouteProgressCalculator`.

Given:

- matched position on route
- total route geometry
- route maneuvers

Calculate:

- traveled distance
- remaining distance
- completion percentage
- next maneuver
- distance to next maneuver

Cache cumulative segment distances so calculations remain efficient.

---

# 18. Off-Route Detection

Do not reroute based on one inaccurate GPS sample.

Implement hysteresis.

Initial suggested logic:

```text
Possible off-route:
distance from route > 30 m

Confirmed off-route:
distance > 30 m for several consecutive valid GPS updates
OR
distance > 50 m for a short sustained period
```

Ignore location updates with very poor horizontal accuracy.

The exact thresholds should be constants that can be tuned during real bicycle testing.

Current implementation uses three consecutive valid fixes more than 30 m away
and a 20-second cooldown. A fix on the route resets the counter; fixes with
horizontal accuracy worse than 50 m are ignored.

---

# 19. Re-Routing

When off-route is confirmed:

```text
current GPS location
        +
original destination
        ↓
RoutingService.calculateRoute()
        ↓
new BicycleRoute
```

Replace:

- route polyline
- maneuvers
- route progress

Show a short UI state:

```text
Route wird neu berechnet …
```

Prevent multiple simultaneous rerouting requests.

Add a cooldown so the app does not reroute continuously.

---

# 20. Turn-by-Turn Instructions

Prefer maneuver information returned by BRouter.

The navigation engine should determine:

- next maneuver
- distance to maneuver

Suggested announcement thresholds:

```text
~200 m
~50 m
at maneuver
```

Avoid replaying the same announcement repeatedly.

Track which announcements have already been spoken.

---

# 21. Voice Navigation

Use:

```swift
AVSpeechSynthesizer
```

Example announcements:

```text
"In 200 Metern links abbiegen."

"In 50 Metern rechts abbiegen."

"Jetzt links abbiegen."

"Du hast dein Ziel erreicht."
```

Use the device language / German initially.

Speech logic belongs in `SpeechService`, not directly in a SwiftUI view.

---

# 22. Arrival Detection

Consider the destination reached when the user is within an appropriate radius.

Initial value:

```text
20–30 meters
```

The value should consider GPS accuracy.

On arrival:

- announce arrival once
- stop active navigation
- reduce location update frequency
- show a simple arrival state

---

# 23. Background Navigation

After basic foreground navigation works, add background navigation.

Required behavior:

- navigation should continue if the screen locks
- route progress should continue
- voice instructions should continue where iOS permits
- location updates should stop or reduce when navigation ends

Only add this after basic route tracking is reliable.

---

# 24. Error Handling

Handle at least:

### No current GPS location

Show:

```text
Standort wird ermittelt …
```

### Location permission denied

Explain why location is required and provide a way to open Settings.

### Search failure

Show a simple retryable message.

### Routing service unavailable

Show:

```text
Route konnte nicht berechnet werden.
Erneut versuchen
```

### No route

Show a specific no-route-found message.

### Poor GPS accuracy

Do not immediately reroute.

---

# 25. Networking Rules

Use:

```swift
URLSession
async/await
```

Requirements:

- cancellation support
- reasonable timeout
- no duplicated routing calls
- explicit HTTP error handling
- typed decoding errors
- log useful development information without exposing unnecessary user location data

---

# 26. Privacy

Minimize stored data.

For MVP:

- do not require account
- do not store location history
- do not upload location except as required for routing
- do not implement analytics initially
- do not store completed rides

Location is used only for:

- showing current position
- route calculation
- navigation
- rerouting

---

# 27. Performance

Routes may contain thousands of coordinates.

Consider:

- cumulative route-distance cache
- efficient route matching
- limiting expensive geometry calculations
- avoiding recreating the entire map view for every GPS update
- performing non-UI calculations away from the main actor where appropriate

---

# 28. Development Milestones

## Milestone 1 – Map and location

Implement:

- SwiftUI project
- MapKit
- location permission
- current location
- map display

Acceptance criteria:

- App starts.
- Map loads.
- User location is displayed.

---

## Milestone 2 – Destination search

Implement:

- search field
- `MKLocalSearchCompleter`
- search results
- destination resolution
- destination marker

Acceptance criteria:

- User can type a place/address.
- Suggestions appear.
- Selecting one shows the destination on the map.

---

## Milestone 3 – BRouter route

Implement:

- `RoutingService`
- `BRouterService`
- GeoJSON parsing
- route drawing

Acceptance criteria:

- User selects destination.
- Bicycle route is fetched.
- Route appears as a polyline.

---

## Milestone 4 – Route preview

Implement:

- distance
- duration
- full-route camera
- Start button

Acceptance criteria:

- Entire route can be previewed.
- Distance and duration are visible.
- Start begins navigation.

---

## Milestone 5 – Basic navigation

Implement:

- high-frequency GPS
- route matcher
- route progress
- remaining distance
- next maneuver

Acceptance criteria:

- Position updates while moving.
- Remaining route distance decreases.
- Next maneuver changes correctly.

---

## Milestone 6 – Voice navigation

Implement:

- speech service
- maneuver announcements
- duplicate suppression

Acceptance criteria:

- User receives timely voice instructions.

---

## Milestone 7 – Off-route and rerouting

Implemented ahead of voice navigation at the user's request after the simulated
ride revealed that deviations did not trigger rerouting.

Implement:

- off-route detector
- hysteresis
- rerouting
- rerouting UI state

Acceptance criteria:

- Leaving the route triggers one sensible reroute.
- GPS noise alone does not constantly reroute.

---

## Milestone 8 – Background navigation

Implement:

- required iOS capabilities
- background location behavior
- screen-lock testing

Acceptance criteria:

- Navigation remains useful with screen locked.
- App behaves correctly after returning to foreground.

---

## Milestone 9 – Real bicycle testing and tuning

Test outdoors.

Tune:

- route deviation threshold
- announcement distances
- GPS filtering
- map zoom
- map heading behavior
- rerouting cooldown
- arrival radius

Do not over-engineer these values before real-world testing.

---

# 29. Unit Tests

At minimum test:

### RouteMatcher

- point exactly on route
- point beside route
- point near segment midpoint
- closest point at segment endpoint
- long route with many segments

### RouteProgressCalculator

- start of route
- middle of route
- end of route
- correct remaining distance
- correct next maneuver

### OffRouteDetector

- isolated inaccurate point
- sustained off-route movement
- return to route
- poor-accuracy samples

Use deterministic coordinate fixtures.

---

# 30. Logging During Development

Add lightweight development logs for:

- current GPS accuracy
- route distance from GPS
- matched route segment
- next maneuver distance
- rerouting decisions
- routing API duration

Do not clutter production UI with these values.

Optionally provide a compile-time DEBUG overlay later.

---

# 31. BRouter Hosting Strategy

Use `https://brouter.de/brouter` directly for development and the first public
release. Running our own BRouter server is not a release requirement.

The official website presents BRouter-Web as a public online routing service.
A 2015 maintainer response directed a third-party app developer to the HTTP API:
https://groups.google.com/g/osm-android-bikerouting/c/ghi7lu2ZjdU

As checked on 2026-10-03, no explicit request quota, third-party app prohibition,
or availability guarantee was found in the official pages reviewed. This does
not establish unlimited use or current approval for an App Store app. Confirm
acceptable app usage and request volume with the maintainers before release.

Keep requests limited to route calculation and necessary rerouting. Preserve
existing rerouting cooldown and error handling. Include BRouter and OpenStreetMap
credits and explain the third-party routing service in the privacy policy.

BRouter's privacy policy says routing coordinates, IP addresses, timestamps,
requested resources, and user agents are logged for two weeks, with an additional
ten days in hosting-provider backups:
https://brouter.de/privacypolicy.html

KETTE does not store location history locally; this does not mean the routing
server does not retain location data.

---

# 32. Backend Scope

Do not build or operate a KETTE backend for the first public release.
If the public service becomes unsuitable, evaluate another hosted routing
provider through the existing `RoutingService` boundary.

---

# 33. Routing Profile Strategy

For the first version, expose exactly one route style:

```text
Bicycle
```

Internally tune it toward:

Preferred:

- dedicated cycleways
- calm residential roads
- paved paths
- good-quality bicycle-compatible paths

Avoid where possible:

- major roads
- high-speed traffic
- unsuitable unpaved tracks

Strongly avoid:

- bicycle-prohibited roads
- unsafe or inappropriate road classes

Do NOT expose BRouter profile details to the user in MVP.

Possible future options:

```text
Fast
Quiet
Mostly cycleways
Gravel
```

but only after the core navigation is proven.

---

# 34. UI Scope

The MVP should have only three meaningful states.

## State 1: Destination search

```text
Map
+
"Where to?" search
```

## State 2: Route preview

```text
Map + route
+
distance
+
duration
+
Start
```

## State 3: Navigation

```text
next maneuver
+
distance to maneuver
+
navigation map
+
remaining time
+
remaining distance
```

That is the complete MVP.

---

# 35. Explicit Non-Goals

Do not implement these unless specifically requested later:

- user accounts
- cloud sync
- ride statistics
- calories
- cadence
- heart rate
- Strava integration
- GPX editor
- route collections
- user-generated routes
- ratings
- comments
- friends
- achievements
- leaderboards
- subscriptions
- ads
- in-app purchases
- Apple Watch app
- CarPlay
- Android
- web application
- offline maps
- offline routing

These may be future projects but are outside the MVP.

---

# 36. Coding Rules for Codex

When making changes:

1. Keep code simple and modular. Use straightforward implementations; avoid speculative features, convoluted abstractions, and exhaustive handling of hypothetical edge cases.
2. Prefer native Apple frameworks.
3. Use Swift concurrency.
4. Avoid third-party packages unless they solve a significant problem.
5. Do not add functionality outside the current milestone.
6. Always write tests first: observe a meaningful failing test before implementing behavior, then make it pass. Include unit tests for geometry/navigation logic.
7. Do not redesign unrelated parts of the codebase.
8. Run builds/tests after meaningful changes.
9. Fix compiler warnings introduced by new code.
10. Keep public APIs documented when behavior is non-obvious.
11. Do not put business logic inside SwiftUI view bodies.
12. Keep route-provider-specific logic inside `BRouterService`.

---

# 37. First Codex Task

Start with only Milestone 1 and Milestone 2.

Suggested prompt:

```text
Implement Milestones 1 and 2 from IMPLEMENTATION_PLAN_KETTE.md.

Build a native iOS 26+ SwiftUI application.

Requirements:
- Use MapKit.
- Show the user's current location.
- Request location permission appropriately.
- Add a destination search field.
- Use MKLocalSearchCompleter for autocomplete.
- Resolve selected results using MKLocalSearch.
- Place a marker for the selected destination.
- Keep the architecture modular.
- Do not implement routing yet.
- Do not add third-party dependencies.
- Add any required Info.plist usage descriptions.
- Build the project and fix any compile errors.
```

After this is working, continue with:

```text
Implement Milestone 3 from IMPLEMENTATION_PLAN_KETTE.md.

Add the RoutingService abstraction and BRouterService implementation.
Fetch a bicycle route from BRouter as GeoJSON and display it as a MapPolyline.
Do not implement navigation yet.
```

Then proceed milestone by milestone.

---

# 38. Definition of MVP Done

The MVP is complete when this exact real-world flow works on an iPhone:

```text
Open app
   ↓
Search destination
   ↓
Select destination
   ↓
Bicycle route appears
   ↓
See distance + duration
   ↓
Tap Start
   ↓
Follow turn-by-turn navigation
   ↓
Hear voice instructions
   ↓
Intentionally leave route
   ↓
App reroutes automatically
   ↓
Reach destination
   ↓
Navigation ends
```

If this works reliably, the core product concept has been validated.
