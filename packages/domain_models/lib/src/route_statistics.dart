import 'package:equatable/equatable.dart';

enum StatisticsPeriod { week, month, allTime }

enum StatisticsInterval { day, month, year }

/// A completed recording, without its GPS trace. Distances are in meters.
class RecordedRouteSummary extends Equatable {
  const RecordedRouteSummary({
    required this.id,
    required this.startedAt,
    required this.distance,
    required this.duration,
  });

  final int id;
  final DateTime startedAt;
  final double distance;
  final Duration duration;

  @override
  List<Object> get props => [id, startedAt, distance, duration];
}

DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

class StatisticsTotals extends Equatable {
  const StatisticsTotals({
    this.distance = 0,
    this.duration = Duration.zero,
    this.routes = 0,
    this.activeDays = 0,
  });

  factory StatisticsTotals.fromRoutes(Iterable<RecordedRouteSummary> routes) {
    var distance = 0.0;
    var duration = Duration.zero;
    var count = 0;
    final days = <DateTime>{};
    for (final route in routes) {
      distance += route.distance;
      duration += route.duration;
      count++;
      days.add(_day(route.startedAt.toLocal()));
    }
    return StatisticsTotals(
      distance: distance,
      duration: duration,
      routes: count,
      activeDays: days.length,
    );
  }

  final double distance;
  final Duration duration;
  final int routes;
  final int activeDays;

  @override
  List<Object> get props => [distance, duration, routes, activeDays];
}

class StatisticsBucket extends Equatable {
  const StatisticsBucket({required this.start, required this.totals});
  final DateTime start;
  final StatisticsTotals totals;

  @override
  List<Object> get props => [start, totals];
}

/// Calendar periods use the current local timezone, including DST boundaries.
/// A recording's full metrics belong to its start day, even across midnight.
class RouteStatistics extends Equatable {
  RouteStatistics._({
    required this.start,
    required this.endExclusive,
    required this.interval,
    required this.totals,
    required List<StatisticsBucket> buckets,
  }) : buckets = List.unmodifiable(buckets);

  factory RouteStatistics.calculate(
    Iterable<RecordedRouteSummary> records, {
    required StatisticsPeriod period,
    required DateTime anchor,
    required DateTime now,
  }) {
    final eligible = records.where((route) => !route.startedAt.isAfter(now));
    final localAnchor = anchor.toLocal();
    final today = _day(now.toLocal());
    final DateTime start;
    final DateTime end;
    var interval = StatisticsInterval.day;
    switch (period) {
      case StatisticsPeriod.week:
        start = DateTime(
          localAnchor.year,
          localAnchor.month,
          localAnchor.day - localAnchor.weekday + 1,
        );
        end = DateTime(start.year, start.month, start.day + 7);
      case StatisticsPeriod.month:
        start = DateTime(localAnchor.year, localAnchor.month);
        end = DateTime(start.year, start.month + 1);
      case StatisticsPeriod.allTime:
        var earliest = today;
        for (final route in eligible) {
          final day = _day(route.startedAt.toLocal());
          if (day.isBefore(earliest)) earliest = day;
        }
        final months =
            (today.year - earliest.year) * 12 +
            today.month -
            earliest.month +
            1;
        interval = months <= 24
            ? StatisticsInterval.month
            : StatisticsInterval.year;
        start = interval == StatisticsInterval.month
            ? DateTime(earliest.year, earliest.month)
            : DateTime(earliest.year);
        end = DateTime(today.year, today.month, today.day + 1);
    }
    final selected = <RecordedRouteSummary>[];
    final grouped = <DateTime, List<RecordedRouteSummary>>{};
    for (final route in eligible) {
      final date = route.startedAt.toLocal();
      if (date.isBefore(start) || !date.isBefore(end)) continue;
      selected.add(route);
      final key = switch (interval) {
        StatisticsInterval.day => _day(date),
        StatisticsInterval.month => DateTime(date.year, date.month),
        StatisticsInterval.year => DateTime(date.year),
      };
      (grouped[key] ??= []).add(route);
    }
    final buckets = <StatisticsBucket>[];
    var date = start;
    while (date.isBefore(end)) {
      buckets.add(
        StatisticsBucket(
          start: date,
          totals: StatisticsTotals.fromRoutes(grouped[date] ?? const []),
        ),
      );
      date = switch (interval) {
        StatisticsInterval.day => DateTime(date.year, date.month, date.day + 1),
        StatisticsInterval.month => DateTime(date.year, date.month + 1),
        StatisticsInterval.year => DateTime(date.year + 1),
      };
    }
    return RouteStatistics._(
      start: start,
      endExclusive: end,
      interval: interval,
      totals: StatisticsTotals.fromRoutes(selected),
      buckets: buckets,
    );
  }

  final DateTime start;
  final DateTime endExclusive;
  final StatisticsInterval interval;
  final StatisticsTotals totals;
  final List<StatisticsBucket> buckets;

  @override
  List<Object> get props => [start, endExclusive, interval, totals, buckets];
}
