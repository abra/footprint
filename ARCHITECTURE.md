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
  join cache writes), route planner (cancel HTTP), photos (join accepted imports), location backend, then SQLite. Screen disposal never owns
  application writes.
- `RootContext` observes the application lifecycle. Preview tracking stops when
  the app is hidden; an active recording keeps its recording mode.
- `routing.dart` injects dependencies into screens. History uses `push` to retain
  map presentation, but recording no longer depends on that navigation choice.
  All screens explicitly use Flutter's platform-adaptive `MaterialPage`.
  `go_router` 18 detects `material_ui.MaterialApp`, not this app's Flutter
  `MaterialApp`, so relying on automatic page selection loses transitions.
  iOS uses the standard horizontal transition and interactive edge-swipe back;
  Android uses its platform transition.
  Cancelling a back swipe keeps the list and its Cubit alive. Completing it
  returns to the same map, camera, and recording session.

## Features

The walking/exploration milestone is specified in [docs/exploration.md](docs/exploration.md).
`ExploreScreen -> ExploreCubit -> RoutePlanner / WalksRepository` adds planning
without replacing free recording. Plans and ordered checkpoints are distinct
from GPS traces. Pure `ExplorationRules` are applied by `ExplorationDao` inside
the GPS write transaction; both native recording paths earn progress without UI
listeners. `MapCubit` and `RouteDetailsCubit` only read that progress. Selection,
route actions and confirmations use bottom/action sheets.

Planning supports loops from the current position and point-to-point walks with
manual A/B selection. `RoutePlanner.generateBetween` sends ordered endpoints
without round-trip options; both snapped endpoints are checked within 100 m.
Point-to-point geometry is bounded to 100 m-20 km and need not close or match a
requested distance. Its final checkpoint is B. Version 2 of the stored JSON plan
includes mode; version 1 still restores as a loop, with no SQLite schema change.
The View owns the active A/B field. Selecting a field highlights it in place;
the next map tap commits the point through the Cubit without a sheet or a
separate confirmation. Panning, cancelling and switching fields do not change
endpoints or an existing preview. A dedicated GPS action resets the start to
current location. Cubit commands own endpoints and invalidate stale requests. Manual points bypass
GPS only for planning, never for starting a recording away from its route start.
The map retains the opposite endpoint while editing A or B; current-location
starts are also labeled A. Endpoint stems keep labels clear of the GPS marker
and each other when their coordinates coincide, without changing coordinates.

Composition owns and disposes `OpenRouteServicePlanner`, which implements the
`RoutePlanner` interface used by Explore. Each generation owns a cancellable
HTTP client. Closing an Explore Cubit cancels presentation requests without
disposing the shared planner or stopping recording. The HeiGIT implementation
owns authentication, GeoJSON parsing, geometry validation and bounded novelty
ranking. Network errors remain explicit; no fabricated fallback is used.

Generation from the current location and Start walk reuse a suitable fix up to 30 seconds old; otherwise
`RecordingService.refreshPreviewLocation` requests a high-accuracy one-shot fix
through `LocationService -> LocationBackend -> DeviceLocation`. Acquisition has
a 15-second deadline and concurrent requests share the same future. It does not
restart tracking or change its 5-meter distance filter. Only the idle preview
may receive the result; newer stream fixes win and late results cannot enter an
active recording. Explore distinguishes GPS acquisition from HTTP generation,
continues automatically on success, and ignores cancelled/closed requests.
GPS recovery clears only location errors, never routing/storage failures.
Regeneration retains the current preview and its novelty estimate through loading,
cancellation and errors. Only a successful response replaces it; the Cubit keeps
one previous preview/estimate for a local undo. Parameter changes and clearing a
route invalidate both snapshots. Generation returns an attempt-specific success
flag so late or cancelled requests cannot switch the View to a different result.
The preview shows distance to its start using a suitable GPS fix. A one-shot expiry
timer invalidates this readiness after 30 seconds without polling or extra GPS
subscriptions. A fresh, distant fix disables Start walk; an expired/unknown fix
allows the existing acquisition flow. Refresh location explicitly requests a fix
without changing the plan or starting a recording. Start always revalidates GPS
and the 100 m rule, regardless of what the View previously displayed.
Start walk returns attempt-specific failure feedback for a visible action sheet;
errors cannot be hidden above the button in a scrolled planning panel or erased
by the next GPS update before they are presented. The 100 m start-distance check
still applies to both modes. Dismissing the sheet keeps the plan and endpoints;
only a successful recording start returns to the map.

`MapScreen`, `RouteListScreen`, and `RouteDetailsScreen` create their Cubits using `BlocProvider`.
Their Views render state and send commands to Cubits; Views do not receive
repositories, SQLite connections, or location services.

`MapCubit` observes `RecordingService`, maps its state for presentation, debounces
address lookups, and handles tile and photo presentation state. Record/Stop/Retry delegate to the
service. Closing the Cubit cancels its view subscriptions and releases its preview
request, without stopping an active recording. Address lookups are not launched
while the app is hidden; stale results cannot overwrite newer coordinates.
Repeated fixes at the same filtered coordinates do not repeat address lookups.

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
place the chart above the metrics. `RouteMetrics.speedHistory` contains filtered
motion estimates (legacy points use segment speeds) at elapsed GPS times;
live clock ticks reuse that immutable list.
The chart is isolated by a repaint boundary and is not driven by marker frames.

Map camera operations and tile rendering belong to the View. Map and Explore
share `CurrentLocationLayer` and `LocationMotion` from `component_library`,
with a View-owned ticker on each screen. `LocationMotion`
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
SQLite, metrics, and photos use filtered GPS fixes, never animation frames.
Recorded fixes also retain original coordinates and sensor measurements.
Explore does not follow the marker automatically after initial positioning;
manual centering targets the displayed location or fits the planned route.
An automatic A endpoint follows the displayed marker, while manual endpoints
and generated routes stay fixed. Routing still uses the actual GPS coordinates.
Explored-area cells are shown only in the Exploration tab, not on Plan route.
The shared position marker is a borderless purple navigation arrow with a
compact, low-opacity shadow centered on its silhouette without a directional
offset, inside a fixed 40px surface. Its size is clamped to
24px at zoom 10 and below and 36px at zoom 16 and above, interpolating linearly
between those zoom levels. Only map events that change the clamped size rebuild
the glyph; sizing adds no ticker and keeps its geographic anchor unchanged.
Until a travel course is known it uses a
static 28px dot. Neither shape pulses. `LocationMotion` derives course from at
least 3m of filtered displacement and publishes it separately at the displayed
buffered leg, not the newest GPS fix. Stationary fixes preserve the last course;
relocations and moving fixes after a signal gap reset it. No compass or additional
persisted sensor fields are required. Turns follow the shortest arc over 240ms,
ignoring changes below 2 degrees once settled. The arrow rotates with the map.
`HeadingMotion` stops after each turn and snaps for reduced motion,
disabled `TickerMode` or a background app. A `RepaintBoundary` isolates drawing.
On the main map, the View owns this motion and shares it with the arrow and
`MapFollowMotion`, so course-up rotation exactly cancels the visible arrow's
geographic heading. Explore keeps its existing freely oriented planning camera.
The center button resumes following after a map gesture, preserving orientation;
while following, it toggles north-up (compass icon) and course-up (arrow icon).
Accessible action labels describe the next action and semantics expose the mode.
`MapState` holds following/orientation choices only, never animation frames.
Mode changes turn the map by the shortest arc over 240ms, without changing zoom
or moving the marker away from the viewport center. Missing course holds the
current rotation; acquiring a course transitions to it. Manual gestures cancel
following and in-flight camera turns. Zoom buttons preserve both choices.
There is no idle rotation ticker, compass subscription or new persisted data.
Heading-only frames update the camera and dependent map layers in course-up,
while keeping screen/controls out of frame updates and retaining cached route
geometry. Camera rotation still incurs rendering work; device profiling is
required to quantify its cost.
`RecordedRouteLayer` styles both recordings and saved previews with a rounded
purple stroke without casing and a faint two-tone vector shadow offset by 2px.
Full maps use a 7px stroke, compact previews 5px. The shadow needs no viewport blur
or new ticker. Both shadows render beneath the colored strokes. Each historical pass
is cached between sample boundaries, sharing the same coordinate list; only the
two-point tail changes each frame.
The tail shadow fades in beyond the cached end cap to avoid a dark overlap spot.
`RecordedRouteMarker` keeps endpoint meanings consistent across recording,
saved previews and details: a coral flag marks the first rendered point and a
filled green location pin marks the last. Timeline endpoints share these colors
and use the same filled finish icon.
Their pole base/pin tip anchors match the line's
coordinates, independent of zoom, map rotation or text scaling. Previews use the
same filtered coordinate list for both the line and its endpoints; single-point
routes show only the start marker. Timeline events use the same symbol meanings
and colors.
Map errors remain visible and can be retried by recreating the tile layer.

`RouteListCubit` handles loading, loaded/empty, and failure states. Late results
cannot overwrite a newer request or emit after the Cubit is closed.
The catalog loads 20 routes per page, debounces name/date searches, and supports
sorting, details/rename, and confirmed deletion. A page reads route headers and
their points in two queries within one transaction, avoiding one query per row.
After stopping, the main map retains the completed trace as a thin, muted line
without a shadow, with subdued start/finish markers and a dismissible "Last route"
notice. Dismissal belongs to `MapCubit` presentation state, never deletes stored
points, survives preview GPS updates, and resets when a new route is created.
Starting a recording hides the old geometry while creation is pending; a failed
start restores its previous visibility. Active and detailed routes keep their
normal styling. Completed planned-walk overlays are not retained on the main map.

The catalog uses static 720x400 PNG thumbnails, never `FlutterMap` instances.
`RouteThumbnail` owns its Cubit; the View only paints state and forwards commands.
Composition owns `RouteSnapshotRepository` from `route_snapshots`. It coalesces
identical requests, renders one thumbnail at a time and cancels work when its last
consumer leaves. Generation is lazy for built list entries, not an initialization
or recording-save dependency, and never prefetches an entire route catalog.
`RouteSnapshotScene` fits every valid route point using flutter_map's camera/CRS
with 72px padding for the line, endpoint glyphs and attribution. The headless
renderer fetches only the tiles of this single viewport, at one zoom, with up to
four concurrent loads, the configured provider/User-Agent and normal tile caching.
It has a 12-second deadline and releases image resources and its provider on exit.
Only a complete rendered map is cached. While loading or offline, the same fitted
route is painted without a basemap; failures expose a retry action, not a spinner.
Images are shown without cropping; attribution remains visible and linked.
Snapshot keys include geometry, tile URL and rendering version, not route names.
The service keeps an 8 MB encoded-image memory cache and a 50 MB temporary disk
cache, validates disk PNGs, atomically replaces files and prunes older geometry
and least-recently-used files. Cache I/O failure does not block displaying a newly
rendered image. Deleting a route cancels its pending snapshot writes and clears
its cache. The OS can evict temporary files; cached previews are not offline maps.
Route details remain interactive; timeline previews still use `RoutePreview`.

`RouteDetailsCubit` loads the route and validates/persists a trimmed name. A
successful Stop completes the route before navigation to the naming screen.
Back without a name retains the completed route with a generated display title;
discarding edits never deletes the route. Active routes cannot be renamed or
deleted, including at the DAO boundary. Failed name saves retain the input.

`StatisticsScreen -> StatisticsCubit -> RoutesRepository -> RouteStatisticsDao`
adds cumulative activity from the history toolbar, preserving the list and map
underneath. The Cubit owns an immutable summary snapshot and period/bucket
selection. Pure `RouteStatistics` groups completed recordings by local start
date: Monday-based weeks, calendar months, or all-time months/years. Overnight
recordings belong entirely to their start date. Duration includes stops; active
days count distinct recording start dates. No activity classification is inferred.
Future starts and active routes are excluded. Calendar construction, not 24-hour
increments, handles DST. Empty periods contain zero-filled buckets.

SQLite v8 adds a derived `route_statistics` table with cascading deletion, leaving
all routes, points, photos and exploration data unchanged. Missing summaries are
calculated lazily, one completed trace at a time, using `RouteMetrics` in a worker
isolate. Reading/calculation does not hold a write transaction. A short conditional
insert tolerates concurrent deletion and duplicate readers. Only distance and
duration return from the worker, never speed histories. Subsequent visits read
summaries, not GPS points; changing periods does not query storage. Start/Stop and
the recording pipeline are unchanged. `SqliteStorage.close` stops further cache
backfill and joins the in-flight operation before closing the connection.

Refresh preserves visible data on failure with an explicit retry; stale requests
and results arriving after Cubit disposal are ignored. Resume reloads the snapshot
and advances the current calendar period, while explicitly browsed past periods
stay pinned. The chart uses selectable, accessible bars with fixed plot height;
labels and metrics reflow at large text sizes. Explanations use an action sheet.

`LocationFilter` is a pure Dart, constant-space processor in
`foreground_location_service`, upstream of persistence and presentation.
`NativeLocationBackend` applies it to preview and iOS recording streams. The
Android `BackgroundRecordingWorker` applies the same processor before writing;
worker messages are never filtered again by the UI isolate. Mode changes/retries
use the newest known fix as an anchor; restored recordings and restarted
Android workers seed from the last persisted point.

Measured accuracy must be finite, positive and no worse than 35 meters. Invalid
coordinates and non-increasing timestamps are rejected. Absent measurements
remain null, not fictitious zeroes. Fixes without an accuracy measurement keep
their geometry unchanged; old routes are not reprocessed. The holding radius is
the larger of 3 meters and the anchor/current accuracy. After 8 seconds without
accepted movement, the state becomes stationary; its departure radius is 1.5
times wider. Departure needs two directionally consistent fixes within a minute,
also accommodating slow distance-filtered updates. Reliable sensor motion can
retain steps of at least 1 meter: speed minus uncertainty must exceed 0.35 m/s,
and uncertainty must not exceed 1 m/s. Unexplained jumps need confirmation;
displacements implying over 100 m/s plus positional uncertainty are held.
Filtering neither pauses recording nor disables GPS. The native 5-meter
distance filter is unchanged.

Each emitted fix preserves its source ID, timestamp, raw coordinates, accuracy,
sensor speed/uncertainty, filtered speed and stationary flag. Held fixes share
accepted coordinates instead of adding a loop. Filtered speed prefers usable
sensor speed (up to 100 m/s); otherwise it uses time between accepted anchors,
avoiding spikes when a held position is released. It becomes zero on a confirmed
stop. Rejected fixes are not stored. The filter has no timers, growing history
or animation-frame work; it processes only incoming fixes.

`RouteMetrics` is a pure Dart GPS estimate using latlong2 geodesic distances.
It skips invalid coordinates and non-increasing timestamps, sums filtered
geometry and uses persisted filtered speeds (sensor/segment fallback for older
data). Average speed uses total elapsed time, including stops. Current speed
also becomes zero after 10 seconds without a sample. MapCubit advances only the
presentation clock once per second while recording in the foreground;
animation positions never enter these calculations.

The first PDF-based milestone implements a full-bleed map with floating controls, a
recording metrics panel, route naming/preview, and a vertical route catalog.
`component_library` owns the Forui theme, common controls/sheets, metric
formatting/widgets, and shared map/preview rendering. Inter and Lucide ship with
Forui; the bundled Roboto Condensed font remains limited to live metrics to
preserve their fixed digit geometry. Production uses
real tile providers; golden tests inject a deliberately synthetic tile.

The map has one primary bottom command (Record/Stop). Explore is a labeled
secondary action in the address bar and hides while recording or transitioning;
history stays available. The header wraps at narrow widths/large text sizes.
Camera and map tools remain separate 48px targets. Press feedback does not scale
the controls and is clipped to the same shape as their surface.
Floating map controls, the Record/Stop command, headers, recording/planning
panels and retry notices use
the borderless `MapSurface` with a shared soft shadow. Scrollable headers and
preview overlays leave space for that shadow without disabling content clipping.
Zoom controls retain an internal divider in either orientation. Input outlines,
selection indicators and in-page separators remain functional boundaries, not
floating surfaces, and do not inherit map shadows.
Map controls use viewport-based positions rather than the space left by headers
and recording statistics. The photo slot has a fixed extent even while absent;
starting/stopping recording, expanding stats and displaying errors cannot shift
the existing controls. Compact viewports use a horizontal toolbar in both idle
and recording states. Header and footer content is constrained to separate areas
and can scroll without covering the 48px controls.

`MaterialApp` and platform-adaptive pages remain the navigation/keyboard host;
`FTheme` wraps the navigator so routes and modal sheets share styling and Forui
accessibility settings. Views use Forui buttons, fields, tiles and selection
controls. Shared wrappers enforce touch sizing and text wrapping, not business
logic. Individually outlined tiles use `AppTileList` with the shared 8px spacing
token; this covers endpoints, achievements and sheet actions.
`AppSheet` gives modal forms and action sheets the same subtle upward shadow
and rounded surface without tinting the background or adding layout padding.
Segmented controls and the zoom toolbar remain visually connected groups.
Loop planning offers a 2x2 grid of 1/3/5/10 km presets. The adjacent custom
distance action opens a numeric-only sheet; custom values remain visible without
selecting a preset. The A/B endpoint form determines the shared settings height;
the Loop grid fills those bounds. Editing and preview are separate View states:
generation opens the result, Edit restores the form without clearing a valid plan,
and Show route returns to that same preview without another request. The panel
wraps its content, with a regular gap before commands, and its maximum height is
viewport-limited, keeping the map visible without a full-screen expansion mode.
The app bar exposes only map centering beside the title. Settings and results have a
scrollbar when they overflow; primary commands and preview tools stay outside the
scroll area. Loop regeneration is a 48 px refresh tool beside
Start walk, with a tooltip and accessibility label. Short, wide panels place
commands beside the form; portrait panels allow more height for large text.
Camera framing uses the laid-out panel height.
Route tolerance
remains unchanged at +/-10%.

After Stop completes, Route details says "Route saved" and naming is optional;
leaving without renaming retains the completed recording. Both the checkmark and
keyboard submission accept a blank name. Unchanged names
finish without a database write; clearing an existing name stores NULL in both
name fields, restoring the date-based label and removing the old search entry.
Name persistence keeps its checkmark and reports pending text instead of replacing
the icon with a spinner.
Reaching the final checkpoint never stops recording automatically: the live summary
says "Recording continues". Checkpoint distances are labeled straight-line, not
remaining walking distance or turn-by-turn guidance.

Local view changes use a shared 180 ms fade-through (`AppMotion`): Loop/A/B fades
inside the endpoint form's bounds, while editor/preview, planning/exploration and statistics
periods use `AppFadeSwitcher`. Outgoing content cannot receive pointer, focus,
or accessibility actions and does not determine the incoming view's height.
Content fades out before the new content fades in, without overlapping labels.
Reduced-motion settings skip transitions, including one already in progress.
Keys represent view/period changes, not GPS, counters, or chart selections;
animation frames do not rebuild their content. Map canvases stay outside these
transitions, and navigation retains platform page transitions.
Modal commands use bottom/action sheets. No extra ticker or state stream
was added to map rendering for the design-system migration.

The photo milestone adds camera/library selection while recording, circular
photo pins, a saved-route gallery, and a paged, zoomable viewer. Photo deletion
requires confirmation and does not delete the source from the user's library.
`RoutePhotosRepository`, in `routes_repository`, owns capture/import/recovery;
its `PhotoPicker` and `PhotoFiles` interfaces isolate the native plugin and disk.
The composition root owns this repository and joins its writes before SQLite
closes. Screens own only subscriptions and presentation state. Stop and duplicate
captures are disabled while a picker/import is in flight; GPS recording continues.
The photo button keeps its camera icon during capture/import/recovery instead
of replacing it with a loading spinner. Failures remain visible and retryable.

Capture intent (route ID, coordinates, timestamp and generated file name) is
committed before opening the picker. The chosen temporary path is journaled,
then the image is copied via an atomic rename to the application support directory
before its metadata is committed. On Android, startup recovery checks
`retrieveLostData`; a recovered photo is never assigned without matching intent.
Database rows store relative file names to tolerate iOS container relocation.
Deletion cascades photo metadata and then removes unreferenced owned files.
Cleanup failures are logged and retried on launch, not reported as a failed
metadata deletion. Originals, unrelated files and pending imports are protected.

Saved route details link to `/routes/:id/timeline`. The timeline has its own
screen-owned `RouteDetailsCubit`, reusing route/photo loading and mutations
without sharing a presentation lifetime with the name editor. Its lazy list
shows start, photos ordered by capture time (ID breaks ties), and finish, with
recorded coordinates and local timestamps. Missing legacy endpoint times remain
unknown; no intermediate stops or movement events are inferred. An overview map
retains the recorded geometry and photo pins.

Photo comments are optional plain text, edited in a bottom sheet from the
timeline or saved-route photo viewer. Empty text removes a comment. The
repository trims and limits text to 1000 grapheme clusters, serializes the write,
and notifies other open screens only after SQLite commits. Failed saves preserve
the editor draft and allow retry; repeated submits are blocked without replacing
the command icon with a spinner. Screen closure cannot cancel an accepted write.
Comments change neither image files nor coordinates/timestamps. Both camera and
gallery attachments use the GPS fix and wall-clock time before opening the native
picker, not shutter-time metadata or EXIF coordinates.

## Data And Services

- `domain_models`: Flutter-independent values with domain types and equality.
- `routes_repository`: typed route lifecycle API and storage-to-domain mappers.
- `route_planning`: cancellable walking-route generation through HeiGIT
  (OpenRouteService). Credentials and the endpoint are injected at composition.
- `sqlite_storage`: explicitly owned connections, `RoutesDao`, and
  `GeocodingCacheDao`, `RoutePhotosDao`, `RouteStatisticsDao`, and `ExplorationDao`. Version 9 migrates versions 1/2/3/4/5/6/7/8 without deleting route
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
  Version 6 adds nullable raw GPS/quality/speed measurements and a default-false
  stationary flag. Legacy geometry, photos and pending captures are preserved.
  Version 7 adds versioned walk plans, ordered checkpoints, discovered geohash
  cells and achievements. The storage package depends on pure domain models to
  run shared exploration rules in the same transaction as the recording write.
  Version 9 adds a default-empty photo comment; old attachments and pending
  capture recovery keep their original coordinates, time and file names.
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
failure/restart, every recording retry operation, migration from versions 1/2/3/4/5/6/7/8,
deduplication, shutdown ordering, and a background writer with no UI connection.
Golden tests cover the map, saving, history, and photo viewer using a bundled
font, fixture tiles, and a photo extracted from the supplied PDF. Layout tests
additionally cover 320px portrait and landscape with 2x text.
GPS tests cover ten-minute stops, slow walking, vehicle speeds, isolated jumps,
poor/missing accuracy, stream restart, filtered write retries and persisted
metadata. A map widget test checks stable geometry/camera with advancing time;
the native workflow also simulates a stop and checks reopened SQLite data.
`make integration
DEVICE=<device-id>` runs the native recording workflow on a simulator/device.

Android uses the Gradle/AGP/Kotlin versions from the Flutter 3.47.2 template.
Built-in Kotlin is enabled; `android.newDsl=false` remains necessary for the
Flutter Gradle plugin's legacy Android extension API.
iOS adopts the UIScene lifecycle and Flutter's current deployment target.

## Remaining Product Work

- GPS filtering is conservative, not a guarantee of meter-level tracking.
  Motion below positional uncertainty may remain held until enough displacement
  accumulates. Coherent drift can still look like real movement; prolonged GPS
  outages retain the existing straight connection between accepted locations.
  Thresholds need physical-device walking/driving traces under real signal
  conditions. Activity-recognition sensors and optional auto-pause are not added.

- The alternative grid catalog from the PDFs and export/sharing
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
