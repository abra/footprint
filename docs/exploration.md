# Walking And Exploration Milestone

## Product Boundary

This is a walking-first, local-profile milestone: choose a loop distance or
start/destination points, preview a walking route, walk its checkpoints, keep
discoveries, and review the saved activity.
Free recording and photos are unchanged. There is no XP economy, account,
leaderboard, POI quest, auto-pause, or automatic recording shutdown at the finish.
Completing the checkpoint sequence and stopping a recording are separate events.
An early stop keeps all recorded data and reached checkpoints.
The preview's Clear route action removes only the unsaved plan and its estimated
new areas. Mode, endpoint and distance selections, map camera, discoveries and saved recordings stay
unchanged. Clearing cannot modify a starting or active recording; pending
generation results cannot restore a cleared preview.

## Ownership

- `RoutePlan` is an immutable proposed path, not a `RouteDM` GPS recording.
  Its versioned payload preserves checkpoint coordinates across restarts.
  Version 2 stores loop/point-to-point mode; version 1 remains readable as a loop.
  Point-to-point plans have no requested distance, only measured path distance.
- `route_planning` implements HeiGIT routing and bounded candidate search
  in `OpenRouteServicePlanner`, behind the `RoutePlanner` interface.
  Each generation owns its cancellable HTTP client. The composition root owns
  the planner; closing the planning Cubit cancels work, not shared GPS recording.
- `ExploreScreen -> ExploreCubit -> RoutePlanner / WalksRepository` follows the
  same screen/Cubit/service boundaries as the existing features. The View owns
  map fitting, tiles, sheets and camera changes. Late requests cannot emit after
  closure or replace a newer mode, endpoint or distance selection.
  Selecting A or B highlights its field in the existing panel. The next map tap
  commits that endpoint immediately, without a sheet or confirmation step.
  Panning, tapping an already selected field, or Cancel/Back cannot mutate the
  plan. Existing markers and route remain visible while selecting. A dedicated
  GPS action resets A to current location. Swapping manual endpoints and
  choosing current location invalidate only the unsaved plan.
- `RecordingService.start(plan: ...)` persists the plan atomically with the
  recording's first fix before starting either native producer. Retries retain
  the intended plan. A missing plan is normal free recording.
- `RoutesDao` includes exploration writes in the same transaction as the GPS
  point. `ExplorationDao` applies the pure `ExplorationRules` to two persisted
  fixes; it does not compute motion policy in SQL. The Android worker and iOS
  recorder therefore use the same logic, with no mounted-screen dependency.
- `WalksRepository` reads progress and caches one immutable plan. MapCubit reads
  after persisted-point changes, never animation frames or metrics clock ticks.
- SQLite v7 adds walks, indexed checkpoints, discovered cells and achievements.
  Versions 1-6 retain routes, GPS metadata, photos and pending captures. Duplicate
  source IDs cannot replay progress. A failed exploration write rolls back its
  GPS fix too. Retrying writes does not duplicate a checkpoint or discovery.

## Routing Contract

The HeiGIT adapter requests `foot-walking` GeoJSON and excludes ferries and fords.
Loops use `round_trip` and at most three candidates. Each request has a 12-second
timeout. Valid loop candidates must start within 100 m of the request, end within
40 m of their start, and have a measured geometry length within 10% of the target.
Invalid geometry and unsuitable lengths do not silently become successful plans.
Access errors, rate limits, network failure and missing configuration are visible.

Point-to-point routing sends ordered A/B coordinates in a single request, without
`round_trip`. Both snapping radiuses are limited to 100 m and response endpoints
are validated against the selections. Walking geometry must be 100 m to 20 km;
its length is calculated from the returned path, without the loop's target-length
tolerance. Checkpoints follow the path and the last one is at B, not back at A.
Short walks may have only a finish checkpoint. No straight-line fallback is used.

Upstream response bodies and credential-bearing network errors are not surfaced
to UI. Advertised distance cannot override measured geometry.

When previously explored cells are available, candidates are ranked by their
unfamiliar-cell fraction and length deviation. Samples are spaced every 40 m,
independent of the provider's vertex density. This is a heuristic, not a promise
of a unique, scenic or safe route. New-area counts are estimates, not earned
progress. Nearby-cell queries are bounded to 1,500 results; densely explored
regions can therefore have overestimated novelty. Global street coverage and
map-matched novelty require a later routing/data design.

Only the start and requested loop distance, or the selected A/B coordinates, are sent to routing; discovery
history stays on device. API keys in Dart defines are for local development, not
private production credentials. A production proxy needs appropriate access
controls and provider quotas. Provider accounts, billing and deployment are not
created by this milestone. Public map tiles remain a separate release decision.

## GPS Rules

Generation from the current location and Start walk require an accurate fix no older than 30 seconds (at
most 5 seconds ahead for clock skew). A stationary preview can legitimately stop
emitting with the native distance filter. When the cached fix is missing, stale
or inaccurate, the app requests a fresh high-accuracy position with a 15-second
deadline and continues automatically. Waiting is a neutral status; denied
permissions, disabled GPS, timeout or insufficient accuracy are actionable
failures. Cancel ignores late results. Tracking frequency and discovery rules
are unchanged; timestamps and accuracy are never fabricated to bypass checks.
Manual A/B planning does not need a GPS fix. Starting a planned recording still
requires the user to be within 100 m of its actual start, independently of mode.

Checkpoint and discovery rules use measured/filtered fixes, never the delayed
visual marker. They require finite positive accuracy no worse than 25 m, no
reliable sensor speed above 4.5 m/s, two monotonically timed fixes 1-30 seconds
apart, and plausible displacement for walking. These thresholds need field tests.

Checkpoints need two fixes whose accuracy circles fit inside a 30 m arrival
radius. Raw coordinates must also be within that radius. Only the next ordered
checkpoint can activate; the previous confirmation cannot be reused for the
next one. The first checkpoint is away from the start, so a loop cannot finish
immediately simply because start and finish coincide.

Discoveries use `dart_geohash` precision 7. Cell dimensions vary with latitude.
Both fixes must lie in the same cell, with their uncertainty circles inside its
boundaries. GPS gaps do not paint interpolated territory; standing near a border
does not farm neighbouring areas. Unknown accuracy does not award progress.
Free recordings also discover cells. Old activities are not retrospectively
converted into discoveries. Deleting a route retains the personal discovery
map and achievements; the cell's former route reference becomes null.

GPS alone cannot prove pedestrian access, distinguish both sides of a wall, or
provide robust anti-cheat. Directions depend on routing data; accessibility,
temporary closures and personal safety are not guaranteed. No speed/night/streak
rewards incentivize unsafe behavior. Automatic route recalculation, voice
navigation, offline tile packs and barrier-aware checkpoint placement remain
future work. Users can always end a walk early without losing their recording.

## Verification

- Domain: geometry/length/closure, immutable plans, cell bounds, GPS uncertainty,
  duplicate times, gaps, vehicle motion and ordered arrivals.
- HTTP: walking payload, coordinate order, credentials, malformed responses,
  bounded retries, novelty ranking, cancellation, timeouts and owned-client close.
- SQLite: upgrades, atomic rollback/retry, duplicate and racing connections,
  early/full completion, reopening and discoveries surviving route deletion.
- Cubits: cancellation, late results, invalid GPS, stale starts, duplicate
  commands, errors and recording ownership after screen closure.
- UI: distance-sheet validation, direct A/B map placement, panning without
  point changes, cancellation, GPS reset, swapping, and recording guards.
  Golden images cover point selection in portrait and landscape at 2x text,
  plus plans and discoveries with synthetic tiles.
- Native integration: both modes via HeiGIT HTTP fixture generation
  through the UI, ordered arrival,
  explicit Stop and reopened native SQLite progress. A background-worker test
  records with the UI connection closed.

Automated tests use simulated GPS and fixture routing/maps, not a live provider
or proof of safe street routes. Real-phone walking, long background recording,
provider coverage and battery usage still require physical-device validation.
