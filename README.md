# FemaleRider — mobile app (Flutter)

One app, two modes: **Customer** (request rides, negotiate fares inDrive-style) and **Driver**
(go online, receive requests, offer/counter, run trips, earnings). Every account starts in
Customer mode. The **only** place to switch is the navigation drawer: "Drive with FemaleRider"
(opens the driver application/status flow, or `POST /api/v1/me/mode {mode: driver}` once approved)
and, in driver mode, "Switch to Customer mode" (asks an online driver to go offline first).

- Flutter 3.50 / Dart 3.14, Android + iOS
- Android applicationId / iOS bundle id: `com.gopangitsolution.femalerider`
- Backend: Laravel API (`/api/v1`) + Laravel Reverb (Pusher protocol v7) — see `../backend`

---

## Architecture

Feature-first clean architecture with Riverpod 3:

```
lib/
  main.dart                 # bootstrap: optional Firebase init, ProviderScope
  app.dart                  # MaterialApp.router, global realtime/push listeners
  core/
    config/                 # env.dart (dart-defines), app_config.dart (/config model), config_repository.dart
    network/                # api_client.dart (dio + auth + envelope), api_envelope.dart (ApiException), json.dart
    storage/                # secure_store.dart (token, device id, flags via flutter_secure_storage)
    realtime/               # pusher_message.dart, pusher_client.dart (Reverb client), realtime_service.dart, live_sync.dart
    notifications/          # push_service.dart (FCM + local notifications, tap routing)
    location/               # location_service.dart (geolocator), driver_tracker.dart (online + pings), app_map.dart
    router/                 # routes.dart, redirect.dart (pure, unit-tested), app_router.dart (go_router)
    theme/                  # app_theme.dart — colors, spacing, radius, typography, ThemeData
    widgets/                # design system: buttons, cards, chips, skeletons, empty/error/offline, dialogs, sheets, FareStepper
    utils/                  # formatters (money/distance/time), polyline decoding
  features/
    auth/                   # splash, onboarding, phone, OTP, SessionController
    account/                # profile setup/edit/photo, settings, sessions, delete account, mode switcher, drawer
    verification/           # account status + eligibility verification / appeal
    customer/               # home map, place search, saved places, coupons
    rides/                  # ride requests, matching (radar) & negotiation (offers, counters)
    trips/                  # live trip, receipt, rating, history, detail (shared by both modes)
    payments/               # payments, refunds
    notifications/          # inbox
    support/                # tickets, FAQs, legal pages
    safety/                 # SOS flow, incident reports
    driver_onboarding/      # application steps, documents, status
    driver/                 # dashboard, online toggle, requests, driver trip
    driver_finance/         # earnings, ledger, payouts, statements
```

Each feature has `data/` (repositories over `ApiClient`), `domain/` (models with defensive
`fromJson`) and `presentation/` (screens, widgets, Riverpod notifiers).

Key rules:

- **Server is the source of truth.** Every critical screen (matching, driver requests, live trip)
  uses `LiveSync`: socket events for instant updates, REST re-fetch on (re)connect / app resume,
  and polling (offers 5 s, trips 8 s) while the socket is down.
- **Envelope everywhere.** `ApiClient` unwraps `{success, message, data, meta, error}` and throws
  `ApiException(message, code, details)`; UI shows `message`, logic branches on `code`
  (`fare_out_of_bounds`, `otp_cooldown`, `driver_not_approved`, `active_trip_exists`, …). 401 → logout.
- **Idempotency.** `POST /rides`, `/offers/{id}/accept`, `/offers/{id}/respond`, `/trips/{id}/complete`,
  `/trips/{id}/cash-collected`, `/refunds`, `/driver/payouts` send an `Idempotency-Key` UUID.
- **Routing guards** (`core/router/redirect.dart`): signed-out → onboarding/login; profile incomplete →
  profile setup; eligibility not approved → account status / verification; driver-only screens require
  driver mode; customer-only screens are hidden in driver mode; active trip/ride is resumed on launch.

### Realtime

`PusherClient` speaks Pusher protocol 7 over `web_socket_channel`:
`ws://HOST:PORT/app/{key}?protocol=7&client=dart&version=1.0` → `pusher:connection_established`
→ `POST /api/v1/broadcasting/auth {socket_id, channel_name}` per private channel → `pusher:subscribe`.
Handles ping/pong, activity timeout, exponential backoff (1 s → 30 s) and resubscription.

Channels: `realtime_channels.user` / `realtime_channels.driver` exactly as returned by `GET /me`,
plus `private-ride.{rideUuid}` and `private-trip.{tripUuid}`. If `/config.realtime.host` is empty
or `127.0.0.1`, the env `WS_HOST` is used.

### Driver location

`DriverTracker` (`core/location/driver_tracker.dart`) streams GPS (Android foreground service /
iOS background location) and posts `POST /driver/location {lat,lng,heading,speed,accuracy,sequence,recorded_at}`
at the server-provided `next_interval_s` with a strictly increasing `sequence`; it pauses when
offline and keeps running during an active trip.

---

## Running

### Prerequisites

```bash
cd mobile_app
flutter pub get
```

Backend running locally: API on `:8000`, Reverb on `:8080`.

### Environment (`--dart-define`)

| Define         | Default                                                   | Notes                          |
|----------------|-----------------------------------------------------------|--------------------------------|
| `API_BASE_URL` | Android emulator `http://10.0.2.2:8000`, iOS sim `http://127.0.0.1:8000` | no trailing `/api/v1` |
| `WS_HOST`      | host of `API_BASE_URL`                                    | Reverb host                    |
| `WS_PORT`      | `8080`                                                    |                                |
| `WS_SCHEME`    | `ws`                                                      | `wss` in production            |
| `APP_ENV`      | `local`                                                   | `local` auto-fills `debug_code` on the OTP screen |
| `APP_VERSION`  | `1.0.0`                                                   | sent with device registration  |
| `GOOGLE_MAPS_ENABLED` | `false`                                            | `true` = Google Maps (needs native keys), else OpenStreetMap |
| `MAP_TILE_URL` | OSM public tiles                                          | tile template for the OSM engine |

All values are read in one place: `lib/core/config/env.dart`.

```bash
# Android emulator / iOS simulator (defaults)
flutter run

# From a file (see env/*.json.example)
flutter run --dart-define-from-file=env/dev.json

# Physical device on the same Wi-Fi (backend: php artisan serve --host=0.0.0.0, Reverb bound to 0.0.0.0)
flutter run --dart-define=API_BASE_URL=http://<LAN-IP>:8000 --dart-define=WS_HOST=<LAN-IP>

# Production-style build
flutter build apk --release --dart-define-from-file=env/prod.json
# Live server (https://femalerider.mytechrcm.com)
flutter build apk --release --dart-define-from-file=env/live.json
```

Cleartext HTTP is allowed **only for local development**: Android debug builds use
`android/app/src/debug/res/xml/network_security_config.xml` + `usesCleartextTraffic` in the debug
manifest; iOS uses ATS `NSAllowsLocalNetworking`.

Demo accounts (local backend, OTP comes back as `data.debug_code`): customer `3001234567`,
driver (car, Karachi) `3007654321`, driver (bike) `3005556667`, pending driver application `3001112223`,
customer awaiting eligibility review `3009998887` — country `+92`. The API allows 5 OTP requests per phone per hour.

---

## Maps (OpenStreetMap now, Google Maps when a key exists)

Every map in the app goes through one widget, `AppMap` (`lib/core/location/app_map.dart`):
markers, route polyline, camera fit/move (`AppMapController`), user location, tap and
camera-idle callbacks (drag-to-set-pickup).

- **Default: OpenStreetMap** via `flutter_map` + `latlong2`, tiles from
  `https://tile.openstreetmap.org/{z}/{x}/{y}.png` with `userAgentPackageName:
  com.gopangitsolution.femalerider` and a visible "© OpenStreetMap contributors" attribution.
  The public OSM servers are for light use only (OSM Tile Usage Policy); for production volume point
  `--dart-define=MAP_TILE_URL=https://<provider>/{z}/{x}/{y}.png` at a commercial OSM tile provider.
- **Google Maps:** build with `--dart-define=GOOGLE_MAPS_ENABLED=true` **and** provide native keys.
  If the flag is set but no key is configured natively, the app falls back to OSM (it never
  initialises Google Maps without a key, so iOS cannot crash).
  - Android: `android/local.properties` (git-ignored) → `MAPS_API_KEY=your-android-key`
    (injected via `manifestPlaceholders` into `com.google.android.geo.API_KEY`).
  - iOS: copy `ios/Flutter/Maps.xcconfig.example` to `ios/Flutter/Maps.xcconfig` and set
    `MAPS_API_KEY=your-ios-key` (feeds `Info.plist → GMSApiKey`; `AppDelegate` calls
    `GMSServices.provideAPIKey` only when non-empty).

## Firebase (push notifications) — project `femalerider-a2c0f`

Push is optional: without config files the app logs "push disabled" and keeps working.

- **Android:** `android/app/google-services.json` (git-ignored). The Google Services Gradle plugin is
  applied automatically when the file exists (`android/app/build.gradle.kts`).
- **iOS:** `ios/Runner/GoogleService-Info.plist` (git-ignored) is referenced by the Runner target's
  *Copy Bundle Resources* phase in `project.pbxproj`, so it ships in the bundle. **A fresh clone must
  have this file present or the iOS build fails** — ask a maintainer for it. Push uses
  `ios/Runner/Runner.entitlements` (`aps-environment`, set to `production` for App Store builds);
  enable the Push Notifications capability for your signing team and upload an APNs key in Firebase.

When Firebase is available the app registers the FCM token right after sign-in (permission is requested
in parallel and does not block registration; on iOS it retries until the APNs token is ready) with `POST /api/v1/devices {token, platform, device_id, device_name, app_version}`, re-registers
on token refresh, shows foreground messages as local notifications (Android channel `femalerider_default`),
handles background/terminated taps (`data.screen` + `trip_id`/`ride_id`) and calls
`DELETE /api/v1/devices {token}` on logout.

## App icon

Generated from `../app_icon.png` (padded to `assets/images/icon_square.png` / `icon_foreground.png`):

```bash
dart run flutter_launcher_icons
```

---

## Tests

```bash
flutter analyze
flutter test                      # unit + widget tests (fakes via Riverpod overrides)
flutter build apk --debug
```

- `test/unit/` — envelope/error parsing + ApiClient (auth header, 401, idempotency), model `fromJson`,
  fare formatting/clamping, polyline, env defaults, map engine selection (OSM vs Google), Pusher frame parsing + client (auth, ping/pong,
  reconnect/resubscribe, backoff), router redirect rules, notification routing, cancellation-policy
  messages, monthly statements, refundable amounts and `my_offer` event payloads.
- `test/widget/` — OTP screen, FareStepper bounds + fare sheet, OfferCard actions, drawer mode switch
  (approved driver, apply flow, server error snackbar, go-offline-first), DriverOnlineToggle states.
- `integration_test/app_test.dart` — customer OTP login against the **real local backend**:
  ```bash
  flutter test integration_test/app_test.dart -d <device-id>
  # e.g. iOS simulator: flutter devices → flutter test integration_test -d <simulator-id>
  ```
  The backend must be running with OTP debug codes exposed (`APP_ENV=local`).
