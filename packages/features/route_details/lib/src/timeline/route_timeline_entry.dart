import 'package:domain_models/domain_models.dart';

enum RouteTimelineKind { start, photo, finish }

class RouteTimelineEntry {
  const RouteTimelineEntry._(this.kind, this.time, {this.photo, this.point});

  final RouteTimelineKind kind;
  final DateTime? time;
  final RoutePhotoDM? photo;
  final RoutePointDM? point;

  static List<RouteTimelineEntry> fromRoute(
    RouteDM route,
    List<RoutePhotoDM> photos,
  ) {
    final ordered = photos.where((photo) => photo.routeId == route.id).toList()
      ..sort((a, b) {
        final time = a.capturedAt.compareTo(b.capturedAt);
        return time == 0 ? a.id.compareTo(b.id) : time;
      });
    return List.unmodifiable([
      RouteTimelineEntry._(
        RouteTimelineKind.start,
        route.startTime,
        point: route.startPoint,
      ),
      for (final photo in ordered)
        RouteTimelineEntry._(
          RouteTimelineKind.photo,
          photo.capturedAt,
          photo: photo,
        ),
      if (route.status == Status.completed)
        RouteTimelineEntry._(
          RouteTimelineKind.finish,
          route.endTime,
          point: route.endPoint,
        ),
    ]);
  }
}
