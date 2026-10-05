# KETTE privacy policy — draft

Updated: 2026-10-04. This draft describes the current app and must be published
at a public URL before App Store submission.

KETTE does not require an account, include analytics or advertising, or save
location history or completed rides. It does not operate a backend.

## Location

KETTE requests location access while using the app to display your position,
calculate bicycle routes, track route progress, and recalculate after deviations.
The current version supports foreground navigation only.

## Apple maps and search

Maps and destination search use Apple's MapKit services. Destination queries are
sent to Apple to obtain suggestions and resolve the selected place. Apple's
services have their own privacy practices; see [Apple's privacy policy](https://www.apple.com/legal/privacy/).

## Routing

Selecting a destination sends starting and destination coordinates to
`https://brouter.de/brouter`. Rerouting sends the updated start and the original
destination. The request uses the trekking bicycle-routing profile.

[BRouter's privacy policy](https://brouter.de/privacypolicy.html), checked on
2026-10-04, says its HTTP logs include routing coordinates, IP addresses,
access times, requested resources, and user-agent information. Logs are retained
for two weeks, with an additional ten days in hosting-provider backups.

BRouter uses OpenStreetMap routing data. See [BRouter](https://brouter.de/) and
[OpenStreetMap attribution](https://www.openstreetmap.org/copyright).

## Before publishing

Add the app publisher's public contact/support link, publish this policy, and
ensure App Store privacy answers reflect the app and the third-party services.
