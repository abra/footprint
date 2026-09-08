import 'dart:async';

import 'package:domain_models/domain_models.dart';

import '../../map/test/fakes.dart';

final timelineStart = DateTime(2026, 9, 9, 10);

RouteDM timelineRoute({Status status = Status.completed}) => RouteDM(
  id: 1,
  name: 'Morning walk',
  startTime: timelineStart,
  endTime: status == Status.completed
      ? timelineStart.add(const Duration(hours: 1))
      : null,
  status: status,
  routePoints: [
    for (final i in [0, 1])
      RoutePointDM(
        id: i,
        routeId: 1,
        latitude: 56 + i * 0.001,
        longitude: 60,
        address: '',
        timestamp: timelineStart.add(Duration(hours: i)),
      ),
  ],
);

RoutePhotoDM timelinePhoto({
  String id = 'photo',
  int minute = 30,
  String comment = '',
}) => RoutePhotoDM(
  id: id,
  routeId: 1,
  path: '/missing.png',
  latitude: 56.0005,
  longitude: 60,
  capturedAt: timelineStart.add(Duration(minutes: minute)),
  comment: comment,
);

class CommentPhotosRepository extends FakeRoutePhotosRepository {
  final controller = StreamController<int>.broadcast();
  Completer<void>? saveGate;
  Completer<List<RoutePhotoDM>>? readGate;
  bool failSave = false;
  bool failRead = false;
  int saves = 0;

  @override
  Stream<int> get changes => controller.stream;

  @override
  Future<List<RoutePhotoDM>> getPhotos(int id) async {
    if (failRead) throw StateError('Read failed');
    if (readGate case final gate?) {
      readGate = null;
      return gate.future;
    }
    return super.getPhotos(id);
  }

  @override
  Future<void> updateComment(int routeId, String id, String comment) async {
    saves++;
    await saveGate?.future;
    if (failSave) throw StateError('Disk full');
    final index = photos.indexWhere(
      (photo) => photo.id == id && photo.routeId == routeId,
    );
    if (index < 0) throw StateError('Photo not found');
    photos[index] = photos[index].copyWith(comment: comment.trim());
    controller.add(routeId);
  }

  @override
  Future<void> dispose() => controller.close();
}
