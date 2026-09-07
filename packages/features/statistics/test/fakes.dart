import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routes_repository/routes_repository.dart';

class StatisticsRepositoryFake extends Fake implements RoutesRepository {
  int reads = 0;
  Future<List<RecordedRouteSummary>> Function() response = () async =>
      statisticsRecords();

  @override
  Future<List<RecordedRouteSummary>> getRecordedSummaries() {
    reads++;
    return response();
  }
}

List<RecordedRouteSummary> statisticsRecords() => [
  for (final (index, distance) in [
    3200.0,
    5100.0,
    0.0,
    8400.0,
    2100.0,
    6700.0,
  ].indexed)
    if (distance > 0)
      RecordedRouteSummary(
        id: index,
        startedAt: DateTime(2026, 9, 7 + index, 10),
        distance: distance,
        duration: Duration(minutes: (distance / 75).round()),
      ),
];

DateTime statisticsNow() => DateTime(2026, 9, 13, 12);
