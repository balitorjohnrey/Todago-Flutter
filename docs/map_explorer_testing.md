# Todago map explorer verification

Verified on 26 October 2026.

## Changes

- Tapping a named Google Maps point of interest on Android forwards its exact place ID, name and coordinates into Todago. Long pressing the map still drops an exact coordinate pin.
- Selecting a place from search or the map requests its Google place details: star rating, rating count, category, opening hours, address, photos and photo credits, phone, website and entrance accessibility, when supplied by Google.
- Get Directions stays in Todago and draws a road route with an origin marker, destination marker, distance and estimated tricycle travel time. The map fits the route.
- The origin comes from the phone's current GPS location. Denied or unavailable GPS produces an actionable error instead of substituting a city-centre origin.
- Google routing uses the selected place ID. The existing OSRM fallback uses the same destination coordinates if Google routing is unavailable.
- If the road network ends short of the selected destination, the exact destination pin remains visible and the card reports the remaining distance. A failed routing service never becomes a straight-line directions route.
- Closing or changing a destination invalidates pending details and route requests, preventing old responses from replacing the current selection.

## Automated verification

`flutter test --reporter expanded`: **28 tests passed**.

The suite verifies native place-event handling, place fields and photo widgets, the exact college destination, both Google and OSRM route parsing, staying inside Todago without launching Google Maps, GPS denial, unavailable APIs, route cancellation, stale results, closing directions, and existing account, ride-entry and payment flows. Google place data and GPS are simulated in these tests; the displayed fixture rating is not a live rating verification.

`dart analyze lib/map_place.dart lib/map_place_taps.dart lib/place_details_card.dart lib/live_map_screen.dart lib/map_service.dart test/ride_entry_controls_test.dart`: checked the changed Dart files.

`flutter build apk --debug --no-pub`: **succeeded**, including the Kotlin native POI bridge. Output: `build/app/outputs/flutter-apk/app-debug.apk`.

## Live service checks and remaining setup

- A live Google Places request using the app's configured key returned `REQUEST_DENIED`, explicitly requiring billing to be enabled on the Google Cloud project. Real Google ratings and photos cannot load until that project has working billing and access to Places API. Confirm that Directions API and Maps SDK for Android are also enabled for the same project. No account or billing settings were changed.
- Google billing setup: https://console.cloud.google.com/project/_/billing/enable
- Google place-detail documentation: https://developers.google.com/maps/documentation/places/web-service/legacy/details
- The project already uses Places API (Legacy). Google documents that existing projects remain supported; a new project requires migration to Places API (New).
- A live OSRM request from the Panabo city-centre coordinates to the supplied college pin returned `Ok`, 3,065.1 metres of road geometry and 39 road points. Its mapped road endpoint was approximately 179 metres from the selected pin. This verifies service availability and explains why the app reports final-access gaps; it does not establish the campus entrance or a route from the user's actual current location.
- No Android phone was connected during verification. Physical-device GPS, native label tapping, and live Google photos/ratings remain to be checked after installing the APK and enabling billing. In-app directions are a route preview, without voice-guided turn-by-turn navigation.
- The native POI bridge added here targets Android, matching the reported app screenshots. Search-based details and route display use the shared Flutter code.

## Phone check after setup

1. Install the updated APK and open Explore map.
2. Tap Davao del Norte State College's named map label. Confirm that the title identifies the college and that available Google rating, information and photos appear. If necessary, search for the college and select the matching search result.
3. Tap Get Directions, allow location access, and confirm that Todago remains in the foreground. Check the origin marker against the phone's actual location and the destination marker against the selected college.
4. Check the road route and any final-access message. Close directions and verify that the same place card remains selected.
