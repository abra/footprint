import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_details/src/timeline/route_timeline_entry.dart';

import 'timeline_fakes.dart';

void main() {
  test(
    'timeline orders photos deterministically between the recorded endpoints',
    () {
      final photos = [
        timelinePhoto(id: 'b'),
        timelinePhoto(id: 'a'),
        timelinePhoto(id: 'first', minute: 2),
      ];
      final entries = RouteTimelineEntry.fromRoute(timelineRoute(), photos);
      expect(entries.first.kind, RouteTimelineKind.start);
      expect(entries.last.kind, RouteTimelineKind.finish);
      expect(entries.map((entry) => entry.photo?.id).whereType<String>(), [
        'first',
        'a',
        'b',
      ]);
      expect(photos.first.id, 'b');
      expect(entries.first.point!.latitude, 56);
      expect(entries.last.point!.latitude, 56.001);
      expect(entries.last.time, timelineStart.add(const Duration(hours: 1)));
    },
  );

  test(
    'routes without photos, GPS points or end time do not invent events',
    () {
      final route = RouteDM(
        id: 1,
        startTime: timelineStart,
        status: Status.completed,
      );
      final entries = RouteTimelineEntry.fromRoute(route, []);
      expect(entries, hasLength(2));
      expect(entries.first.point, isNull);
      expect(entries.last.time, isNull);
      expect(entries.last.point, isNull);
      expect(
        RouteTimelineEntry.fromRoute(timelineRoute(status: Status.active), []),
        hasLength(1),
      );
    },
  );

  test(
    'a comment changes equality without changing capture coordinates or time',
    () {
      final photo = timelinePhoto();
      final changed = photo.copyWith(comment: 'View from the bridge');
      expect(changed, isNot(photo));
      expect(changed.latitude, photo.latitude);
      expect(changed.longitude, photo.longitude);
      expect(changed.capturedAt, photo.capturedAt);
      expect(changed.copyWith(comment: ''), photo);
    },
  );
}
