import 'dart:async';
import 'dart:collection';

import 'package:domain_models/domain_models.dart';
import 'package:foreground_location_service/foreground_location_service.dart';
import 'package:routes_repository/routes_repository.dart';

/// Persists before publishing: no UI listener is needed for a point to survive.
class BackgroundRecordingWorker {
  BackgroundRecordingWorker({
    required RoutesRepository routesRepository,
    required this.onSaved,
    required this.onError,
  }) : _routes = routesRepository;

  final RoutesRepository _routes;
  final void Function(LocationDM) onSaved;
  final void Function(Object, StackTrace) onError;
  final _pending = Queue<LocationDM>();
  StreamSubscription<LocationDM>? _subscription;
  Future<void>? _flushing;
  int? _routeId;
  bool _accepting = false;

  Future<void> start(Stream<LocationDM> locations) async {
    if (_subscription != null) throw StateError('Recorder already started.');
    final active = await _routes.getActiveRoute();
    if (active == null) throw StateError('No active route to record.');
    _routeId = active.id;
    _accepting = true;
    final filter = LocationFilter(
      initialLocation: active.endPoint?.toLocation(),
    );
    _subscription = filter
        .bind(locations)
        .listen(
          (location) {
            if (!_accepting) return;
            if (!location.hasValidCoordinates) {
              onError(
                const FormatException('Invalid GPS coordinates.'),
                StackTrace.current,
              );
              return;
            }
            _pending.add(location);
            unawaited(flush().catchError(onError));
          },
          onError: onError,
          onDone: () {
            if (_accepting) {
              onError(
                StateError('Background GPS stream stopped.'),
                StackTrace.current,
              );
            }
          },
        );
  }

  Future<void> flush() =>
      _flushing ??= _flush().whenComplete(() => _flushing = null);

  Future<void> _flush() async {
    while (_pending.isNotEmpty) {
      final point = _pending.first;
      final inserted = await _routes.addPoint(_routeId!, point);
      _pending.removeFirst();
      if (inserted) onSaved(point);
    }
  }

  Future<void> stop() async {
    _accepting = false;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _flushing;
    } on Object {
      // Retained points are retried below; a failed stop can be retried too.
    }
    await flush();
  }
}
