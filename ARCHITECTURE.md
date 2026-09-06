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
  join cache writes), photos (join accepted imports), location backend, then SQLite. Screen disposal never owns
  application writes.
- `RootContext` observes the application lifecycle. Preview tracking stops when
  the app is hidden; an active recording keeps its recording mode.
- `routing.dart` injects dependencies into screens. History uses `push` to retain
  map presentation, but recording no longer depends on that navigation choice.
  All three screens explicitly use Flutter's platform-adaptive `MaterialPage`.
  `go_router` 18 detects `material_ui.MaterialApp`, not this app's Flutter
  `MaterialApp`, so relying on automatic page selection loses transitions.
  iOS uses the standard horizontal transition and interactive edge-swipe back;
  Android uses its platform transition.
  Cancelling a back swipe keeps the list and its Cubit alive. Completing it
  returns to the same map, camera, and recording session.

## Features

`MapScreen`, `RouteListScreen`, and `RouteDetailsScreen` create their Cubits using `BlocProvider`.
Their Views render state and send commands to Cubits; Views do not receive
repositories, SQLite connections, or location services.

`MapCubit` observes `RecordingService`, maps its state for presentation, debounces
address lookups, and handles tile and photo presentation state. Record/Stop/Retry delegate to the
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

The recording statistics panel starts with four left-aligned metrics (PDF
Recording State 2). Tapping switches to the speed chart and a two-column grid
(Recording State 1), or back. `MapCubit` owns this presentation preference,
preserves it across GPS updates/navigation, and resets it for a new session.
Live values use fixed 20px tabular figures and 12px units, with no per-reading
font fitting. Numbers and units share a baseline with a constant 4px gap;
unused width stays after the value-unit pair, never between the number and unit.
The compact row reserves three-digit widths for both speed groups, so crossing
9/10 or 99/100 in either speed cannot move neighbouring groups. Distance and
duration remain content-sized, with spare width shared equally between the four
slots; gaining a digit in distance or duration can redistribute these gaps.
Template measurements stay cached; no animation is added. The expanded two-column grid has fixed
column widths. Three-digit speeds, four-digit distances, and three-digit hours
determine whether four, two, or one column fits; this choice depends on these
templates and accessibility settings, never the current readings. Narrow expanded panels
place the chart above the metrics. `RouteMetrics.speedHistory` contains measured
segment speeds at elapsed GPS times; live clock ticks reuse that immutable list.
The chart is isolated by a repaint boundary and is not driven by marker frames.

Map camera operations and tile rendering belong to the View. `LocationMotion`
plays buffered GPS fixes along geodesic segments without easing at each fix;
the following camera uses that same position. Presentation delay adapts to the
GPS timestamp interval, targeting 1.2 to 4 seconds with 200 ms jitter headroom.
Playback speed adjusts gradually when the delay changes, never rewinding or extrapolating
beyond the latest fix. It drains the buffer and stops its ticker when updates
stop; stationary fixes do not start it. Segment distances and bearings are cached,
and animation frames stay in the View, not Cubit or storage. Playback uses
Flutter's ticker clock; stale/duplicate GPS timestamps and
invalid coordinates are ignored. First fixes, jumps over 500 meters, gaps of
10 seconds, reduced-motion settings, and updates while the map is hidden snap
immediately. The buffer is capped at 32 samples and 8 seconds of backlog;
overflow resets to the latest fix. Irregular updates beyond the bounded delay
can still cause pauses. `RouteTrace` reveals the active route up to the marker's
playback timestamp, with a two-point animated tail ending at the marker. Its
historical polyline is cached between sample boundaries; binary search finds
the visible prefix without scanning/copying the whole route each frame. The
timestamp index is monotonic even for late samples, preserving recorded order.
No line is drawn before playback reaches the recording's first point. Completed
routes show their full recorded geometry, independent of preview movement.
SQLite, metrics, and photos still use original GPS samples, never animation
frames. Map errors remain visible and can be retried by recreating the tile layer.

`RouteListCubit` handles loading, loaded/empty, and failure states. Late results
cannot overwrite a newer request or emit after the Cubit is closed.
The catalog loads 20 routes per page, debounces name/date searches, and supports
sorting, details/rename, and confirmed deletion. A page reads route headers and
their points in two queries within one transaction, avoiding one query per row.

`RouteDetailsCubit` loads the route and validates/persists a trimmed name. A
successful Stop completes the route before navigation to the naming screen.
Back without a name retains the completed route with a generated display title;
discarding edits never deletes the route. Active routes cannot be renamed or
deleted, including at the DAO boundary. Failed name saves retain the input.

`RouteMetrics` is a pure Dart GPS estimate using latlong2 geodesic distances.
It skips invalid coordinates and non-increasing timestamps. Average speed uses
total elapsed time, including stops; current/max speed are segment estimates,
not sensor measurements. Current speed becomes zero after 10 seconds without a
sample. MapCubit advances only the presentation clock once per second while
recording in the foreground; animation positions never enter these calculations.
GPS noise/outliers are not yet filtered using accuracy or activity-specific rules.

The first PDF-based milestone implements a full-bleed map with floating controls, a
recording metrics panel, route naming/preview, and a vertical route catalog.
`component_library` owns the visual tokens, bundled Roboto Condensed font,
metric formatting/widgets, and shared map/preview rendering. Production uses
real tile providers; golden tests inject a deliberately synthetic tile.

The photo milestone adds camera/library selection while recording, circular
photo pins, a saved-route gallery, and a paged, zoomable viewer. Photo deletion
requires confirmation and does not delete the source from the user's library.
`RoutePhotosRepository`, in `routes_repository`, owns capture/import/recovery;
its `PhotoPicker` and `PhotoFiles` interfaces isolate the native plugin and disk.
The composition root owns this repository and joins its writes before SQLite
closes. Screens own only subscriptions and presentation state. Stop and duplicate
captures are disabled while a picker/import is in flight; GPS recording continues.

Capture intent (route ID, coordinates, timestamp and generated file name) is
committed before opening the picker. The chosen temporary path is journaled,
then the image is copied via an atomic rename to the application support directory
before its metadata is committed. On Android, startup recovery checks
`retrieveLostData`; a recovered photo is never assigned without matching intent.
Database rows store relative file names to tolerate iOS container relocation.
Deletion cascades photo metadata and then removes unreferenced owned files.
Cleanup failures are logged and retried on launch, not reported as a failed
metadata deletion. Originals, unrelated files and pending imports are protected.

## Data And Services

- `domain_models`: Flutter-independent values with domain types and equality.
- `routes_repository`: typed route lifecycle API and storage-to-domain mappers.
- `sqlite_storage`: explicitly owned connections, `RoutesDao`, and
  `GeocodingCacheDao`, and `RoutePhotosDao`. Version 5 migrates versions 1/2/3/4 without deleting route
  data. Nullable `source_id` preserves legacy points; a unique per-route sample
  index makes repeated delivery idempotent. Transactions reject a second active
  route and prevent appending to a completed route. The Android worker has an
  independent connection to the same database, not a shared connection lifetime.
  File-backed connections use WAL, including Android's native open configuration
  in the application manifest. Native busy waits are disabled: blocking
  sqflite's shared Android worker can prevent the other connection from committing.
  DAO writes retry only `SQLITE_BUSY` (including extended codes) asynchronously,
  replaying whole rolled-back transactions. Retries stop after eight attempts
  with 1.27 seconds of total backoff; other errors propagate immediately.
  Version 4 adds nullable route names and Unicode-lowercased search names.
  Version 5 adds photo metadata and a single pending-capture journal with foreign keys.
- `foreground_location_service`: `LocationService` contract and its platform
  implementation. Modes are stopped, preview, and recording. Transitions are
  serialized; startup failures, stream errors, and stream completion can be
  retried. `LocationBackend` is the testable platform boundary. Preview uses
  Geolocator without an Android foreground task or Apple background updates.
  iOS recording uses Apple background location settings. Android recording uses
  `BackgroundRecordingTask` from `recording_service`; it saves each point before
  publishing it to the UI and acknowledges Stop only after draining writes.
  The map exposes the pending Start/Stop action separately from recording status;
  its disabled button remains opaque without a loading spinner. Start immediately
  displays Stop; a red dot pulses while recording and stays still during transitions.
  Stop labels the save operation until completion. The dot animates in its own
  repaint boundary, without Cubit emissions, and respects reduced motion and TickerMode.
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
failure/restart, every recording retry operation, migration from versions 1/2/3/4,
deduplication, shutdown ordering, and a background writer with no UI connection.
Golden tests cover the map, saving, history, and photo viewer using a bundled
font, fixture tiles, and a photo extracted from the supplied PDF. Layout tests
additionally cover 320px portrait and landscape with 2x text.
`make integration
DEVICE=<device-id>` runs the native recording workflow on a simulator/device.

Android uses the Gradle/AGP/Kotlin versions from the Flutter 3.47.2 template.
Built-in Kotlin is enabled; `android.newDsl=false` remains necessary for the
Flutter Gradle plugin's legacy Android extension API.
iOS adopts the UIScene lifecycle and Flutter's current deployment target.

## Remaining Product Work

- The optional chart and alternative grid catalog from the PDFs, and export/sharing
  remain separate product work. There are no placeholder chart controls. Active route details are
  a read-only snapshot; live statistics remain on the recording screen.
- Android point persistence does not depend on a UI listener while its foreground
  task is running. This does not promise execution after an OS force-stop,
  permission revocation, or storage failure. iOS recording is app-owned and uses
  background location delivery, but it does not implement native persistence or
  relaunch after force-quit. Long trips and process/permission interruption need
  physical-device validation on both platforms.
- Integration tests simulate GPS input and photo selection and serve fixture tiles locally. Physical
  device permission flows, long background trips, battery use, and real tile
  provider availability still require device testing.
- Photo recovery handles a persisted capture intent and a recoverable picker file;
  an image removed from the OS cache before import cannot be reconstructed.
  Camera permission dialogs, HEIC support, and Android activity destruction still
  need physical-device validation. Library photos use the capture-time GPS fix,
  not EXIF coordinates. No photo upload, EXIF editing, or gallery-wide access is implemented.
- Public OSM tiles are the default for development. Configure a suitable
  provider and attribution before distribution. Error suppression is not a
  substitute for provider availability.
- Release signing and store delivery remain separate setup tasks.

## References

- [Flutter architecture recommendations](https://docs.flutter.dev/app-architecture/recommendations)
- [Flutter dependency injection](https://docs.flutter.dev/app-architecture/case-study/dependency-injection)
- [flutter_foreground_task platform requirements](https://pub.dev/packages/flutter_foreground_task)
- [image_picker platform and recovery requirements](https://pub.dev/packages/image_picker)
