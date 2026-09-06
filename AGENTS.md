# Project Conventions

- Use Flutter 3.47.2 through FVM. Run `make get` after dependency changes.
- Keep the root Dart pub workspace and lockfile consistent.
- Follow `routing -> Screen -> Cubit -> Repository/Service -> DAO/plugin`.
- Views receive state, Cubit commands, and UI configuration, not data services.
- Screens close only their own Cubits/subscriptions. Composition owns shared
  services and SQLite; do not introduce database singletons.
- Recording belongs to `recording_service`, never a screen Cubit. Preserve the
  shutdown order: stop the producer, drain recording/cache writes, close SQLite.
- Keep background point delivery idempotent and retry the failed operation,
  including route completion. Preview GPS must not enable background recording.
- Await initialization and preserve data during schema migrations.
- Add regression tests for behavior changes. Use `make verify` for the workspace
  and `make integration DEVICE=<id>` for the native workflow.
- Keep `ARCHITECTURE.md` aligned with actual behavior and known product gaps.
- Do not edit Readflex or copy its unrelated product features into this app.
