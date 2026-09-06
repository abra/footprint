# Footprint

A Flutter application for recording routes on a map. The current implementation
records GPS points in SQLite and lists active and saved routes.

## Development

Requires FVM, Flutter 3.47.2, and the platform tools for Android or iOS.

```sh
fvm use 3.47.2
make get
make verify
make run
```

The repository is a Dart pub workspace. Resolve dependencies from the root;
commit the root lockfile together with dependency changes.

## Verification

```sh
make test
make build-android
make build-ios
fvm flutter devices
make integration DEVICE=<simulator-or-device-id>
```

Tests cover domain values, GPS modes/recovery, recording failures and retries,
bounded geocoding, Cubits, SQLite CRUD/migrations/reopening, shutdown ordering,
widget states, and recording without a mounted map. A background-writer test
closes the UI database connection and verifies that subsequent samples survive.
The integration test uses native SQLite, simulated locations, and local tiles.

## Map Provider

The default is OpenStreetMap. Override the provider and its attribution together:

```sh
fvm flutter run \
  --dart-define='TILE_URL_TEMPLATE=https://your-provider.example/{z}/{x}/{y}.png' \
  --dart-define='TILE_ATTRIBUTION=Your provider attribution' \
  --dart-define='TILE_ATTRIBUTION_URL=https://your-provider.example/attribution'
```

The OSM development warning is informational. Failed downloads show a retry
banner; they are not hidden as successful transparent tiles. Check the
[OSM tile usage policy](https://operations.osmfoundation.org/policies/tiles/)
when selecting a provider.

## Architecture And Status

See [ARCHITECTURE.md](ARCHITECTURE.md) for package responsibilities and the
Readflex conventions adopted here.

Android recording persists points in its foreground task before notifying the
UI. iOS uses app-owned recording with background location updates. Neither is a
promise of execution after force-stop; long background trips and real permission
flows still need physical-device testing.

Route details, sharing/export, and statistics remain product work. Android
release builds still require production signing.
