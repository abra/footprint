import 'package:domain_models/domain_models.dart';
import 'package:test/test.dart';

RecordedRouteSummary summary(
  DateTime start, {
  int id = 1,
  double distance = 1000,
  Duration duration = const Duration(minutes: 20),
}) => RecordedRouteSummary(
  id: id,
  startedAt: start,
  distance: distance,
  duration: duration,
);

void main() {
  final now = DateTime(2026, 9, 13, 12);
  RouteStatistics calculate(
    List<RecordedRouteSummary> records, {
    StatisticsPeriod period = StatisticsPeriod.week,
    DateTime? anchor,
  }) => RouteStatistics.calculate(
    records,
    period: period,
    anchor: anchor ?? now,
    now: now,
  );

  test('calendar week is Monday to Sunday, with zero-filled days', () {
    final data = calculate([
      summary(DateTime(2026, 9, 6, 23, 59)),
      summary(DateTime(2026, 9, 7)),
      summary(DateTime(2026, 9, 7, 10), id: 2, distance: 0),
      summary(DateTime(2026, 9, 13, 10), id: 3),
      summary(DateTime(2026, 9, 14)),
    ]);
    expect(data.start, DateTime(2026, 9, 7));
    expect(data.endExclusive, DateTime(2026, 9, 14));
    expect(data.buckets, hasLength(7));
    expect(data.buckets.map((b) => b.totals.routes), [2, 0, 0, 0, 0, 0, 1]);
    expect(
      data.totals,
      const StatisticsTotals(
        distance: 2000,
        duration: Duration(hours: 1),
        routes: 3,
        activeDays: 2,
      ),
    );
    expect(() => data.buckets.clear(), throwsUnsupportedError);
  });

  test('month handles leap day and an exclusive next-month boundary', () {
    final data = calculate(
      [
        summary(DateTime(2024, 1, 31)),
        summary(DateTime(2024, 2, 29, 23, 59)),
        summary(DateTime(2024, 3)),
      ],
      period: StatisticsPeriod.month,
      anchor: DateTime(2024, 2, 15),
    );
    expect(data.buckets, hasLength(29));
    expect(data.totals.routes, 1);
    expect(data.buckets.last.start, DateTime(2024, 2, 29));
  });

  test('overnight recordings belong entirely to their local start date', () {
    final data = calculate([
      summary(DateTime(2026, 9, 7, 23, 50), duration: const Duration(hours: 2)),
    ]);
    expect(data.buckets.first.totals.duration, const Duration(hours: 2));
    expect(data.buckets[1].totals.routes, 0);
  });

  test('UTC and local timestamps representing one day share a bucket', () {
    final local = DateTime(2026, 9, 8, 0, 10);
    final data = calculate([summary(local), summary(local.toUtc(), id: 2)]);
    expect(data.totals.activeDays, 1);
    expect(data.buckets[1].totals.routes, 2);
  });

  test('empty history has finite zeros and excludes future timestamps', () {
    final data = calculate([
      summary(now.add(const Duration(seconds: 1))),
    ], period: StatisticsPeriod.allTime);
    expect(data.totals, const StatisticsTotals());
    expect(data.buckets, hasLength(1));
    expect(data.buckets.single.totals.distance.isFinite, isTrue);
  });

  test(
    'all-time monthly buckets include empty months and all saved routes',
    () {
      final data = calculate([
        summary(DateTime(2026, 6, 1)),
        summary(DateTime(2026, 9, 13)),
      ], period: StatisticsPeriod.allTime);
      expect(data.interval, StatisticsInterval.month);
      expect(data.buckets.map((b) => b.totals.routes), [1, 0, 0, 1]);
      expect(data.totals.routes, 2);
    },
  );

  test('long histories use yearly buckets without dropping old totals', () {
    final data = calculate([
      summary(DateTime(2016, 12, 31)),
      summary(DateTime(2026, 9, 1)),
    ], period: StatisticsPeriod.allTime);
    expect(data.interval, StatisticsInterval.year);
    expect(data.buckets, hasLength(11));
    expect(data.totals.distance, 2000);
    expect(data.buckets.first.totals.routes, 1);
  });

  test('calendar days remain distinct across DST transitions and year end', () {
    for (final anchor in [
      DateTime(2026, 3, 8),
      DateTime(2026, 11, 1),
      DateTime(2026, 1, 1),
    ]) {
      final data = calculate([], anchor: anchor);
      expect(data.buckets, hasLength(7));
      expect(data.start.weekday, DateTime.monday);
      expect(data.buckets.last.start.weekday, DateTime.sunday);
      expect(data.buckets.map((b) => b.start).toSet(), hasLength(7));
      expect(data.buckets.every((b) => b.start.hour == 0), isTrue);
    }
  });
}
