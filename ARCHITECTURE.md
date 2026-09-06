# Footprint Architecture

The application follows the feature boundaries used by Readflex:

`routing -> Screen -> Cubit -> Repository / Service -> DAO / platform plugin`

## Application Layer

- `lib/main.dart` delegates to `starter()`.
- `starter.dart` installs error handlers and `AppBlocObserver`, then composes
  dependencies. Concurrent initialization retries are rejected.
- `composition.dart` validates `ApplicationConfig`, awaits SQLite initialization,
  creates services and repositories, and rolls back resources on failure.
- `DependenciesContainer` exposes application-owned resources through
  `DependenciesScope`. Tests can substitute dependencies explicitly.
- `ResourceDisposer` closes resources once, in reverse registration order:
  recording (stop input, drain accepted points), geocoding (cancel network and
  join cache writes), location backend, then SQLite. Screen disposal never owns
  application writes.
- `RootContext` observes the application lifecycle. Preview tracking stops when
  the app is hidden; an active recording keeps its recording mode.
- `routing.dart` injects dependencies into screens. History uses `push` to retain
  map presentation, but recording no longer depends on that navigation choice.

## Features

`MapScreen` and `RouteListScreen` create their Cubits using `BlocProvider`.
Their Views render state and send commands to Cubits; Views do not receive
repositories, SQLite connections, or location services.

`MapCubit` observes `RecordingService`, maps its state for presentation, debounces
address lookups, and handles tile failure state. Record/Stop/Retry delegate to the
service. Closing the Cubit cancels its view subscriptions and releases its preview
request, without stopping an active recording. Address lookups are not launched
while the app is hidden; stale results cannot overwrite newer coordinates.

`recording_service` owns the session, accepted-point queue, persisted sample IDs,
restoration, and operation-specific failures. The phases are idle, starting,
recording, and stopping. Failed Stop retains the stopping intent; Retry repeats
both the pending writes and route completion. A GPS recovery cannot clear a
persistence failure. Disposal rejects new input, stops the producer, and drains
accepted writes before the database is closed. Disposal does not mark an
interrupted route completed; reopening restores it as active.

Map camera operations and tile rendering belong to the View. `LocationMotion`
interpolates the displayed marker over 700 ms; the following camera uses that
same position. New fixes retarget from the visible position, without queuing
animations. First fixes, jumps over 500 meters, reduced-motion settings, and
updates while the map is hidden snap immediately. SQLite and the route polyline
use original GPS samples, never animation frames. Map errors remain visible and
can be retried by recreating the tile layer.

`RouteListCubit` handles loading, loaded/empty, and failure states. Late results
cannot overwrite a newer request or emit after the Cubit is closed.

## Data And Services

- `domain_models`: Flutter-independent values with domain types and equality.
- `routes_repository`: typed route lifecycle API and storage-to-domain mappers.
- `sqlite_storage`: explicitly owned connections, `RoutesDao`, and
  `GeocodingCacheDao`. Version 3 migrates versions 1/2 without deleting route
  data. Nullable `source_id` preserves legacy points; a unique per-route sample
  index makes repeated delivery idempotent. Transactions reject a second active
  route and prevent appending to a completed route. The Android worker has an
  independent connection to the same database, not a shared connection lifetime.
- `foreground_location_service`: `LocationService` contract and its platform
  implementation. Modes are stopped, preview, and recording. Transitions are
  serialized; startup failures, stream errors, and stream completion can be
  retried. `LocationBackend` is the testable platform boundary. Preview uses
  Geolocator without an Android foreground task or Apple background updates.
  iOS recording uses Apple background location settings. Android recording uses
  `BackgroundRecordingTask` from `recording_service`; it saves each point before
  publishing it to the UI and acknowledges Stop only after draining writes.
  Structured messages include startup/shutdown acknowledgements and errors.
- `geocoding_manager`: platform geocoding, rate-limited Nominatim fallback and
  an optional SQLite cache. At most one lookup runs and one latest request waits.
  Superseded queued lookups complete without an address. Lookups have deadlines;
  disposal cancels waiting work, closes the HTTP client, and joins cache writes.
  Cache failures do not prevent a network lookup.
- `component_library`: shared theme and UI primitives.

The existing SQLite engine is retained. Readflex's use of Drift is an
implementation choice, not a prerequisite for these ownership boundaries.

## Toolchain And Dependencies

Flutter 3.47.2 / Dart 3.13.2 are pinned in `.fvmrc` and the SDK constraints.
All packages share one Dart pub workspace and root `pubspec.lock`. This differs
from Readflex's per-package dependency resolution but preserves feature isolation
and prevents different dependency versions within the same application.

`make get` resolves dependencies once. `make verify` checks formatting, analyzes
the workspace, and runs unit, database, and widget tests, including stream
failure/restart, every recording retry operation, migration from versions 1/2,
deduplication, shutdown ordering, and a background writer with no UI connection.
`make integration
DEVICE=<device-id>` runs the native recording workflow on a simulator/device.

Android uses the Gradle/AGP/Kotlin versions from the Flutter 3.47.2 template.
Built-in Kotlin is enabled; `android.newDsl=false` remains necessary for the
Flutter Gradle plugin's legacy Android extension API.
iOS adopts the UIScene lifecycle and Flutter's current deployment target.

## Remaining Product Work

- Route details, export/sharing, and computed distance/speed are not implemented.
- Android point persistence does not depend on a UI listener while its foreground
  task is running. This does not promise execution after an OS force-stop,
  permission revocation, or storage failure. iOS recording is app-owned and uses
  background location delivery, but it does not implement native persistence or
  relaunch after force-quit. Long trips and process/permission interruption need
  physical-device validation on both platforms.
- Integration tests simulate GPS input and serve fixture tiles locally. Physical
  device permission flows, long background trips, battery use, and real tile
  provider availability still require device testing.
- Public OSM tiles are the default for development. Configure a suitable
  provider and attribution before distribution. Error suppression is not a
  substitute for provider availability.
- Release signing and store delivery remain separate setup tasks.

## References

- [Flutter architecture recommendations](https://docs.flutter.dev/app-architecture/recommendations)
- [Flutter dependency injection](https://docs.flutter.dev/app-architecture/case-study/dependency-injection)
- [flutter_foreground_task platform requirements](https://pub.dev/packages/flutter_foreground_task)
