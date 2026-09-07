import 'package:domain_models/domain_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routes_repository/routes_repository.dart';

class StatisticsState {
  const StatisticsState({
    this.period = StatisticsPeriod.week,
    this.data,
    this.loading = false,
    this.failed = false,
    this.canGoNext = false,
    this.selected = 0,
  });

  final StatisticsPeriod period;
  final RouteStatistics? data;
  final bool loading;
  final bool failed;
  final bool canGoNext;
  final int selected;

  StatisticsState copyWith({
    StatisticsPeriod? period,
    RouteStatistics? data,
    bool? loading,
    bool? failed,
    bool? canGoNext,
    int? selected,
  }) => StatisticsState(
    period: period ?? this.period,
    data: data ?? this.data,
    loading: loading ?? this.loading,
    failed: failed ?? this.failed,
    canGoNext: canGoNext ?? this.canGoNext,
    selected: selected ?? this.selected,
  );
}

class StatisticsCubit extends Cubit<StatisticsState> {
  StatisticsCubit({required this._repository, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      super(const StatisticsState());

  final RoutesRepository _repository;
  final DateTime Function() _clock;
  DateTime? _anchor;
  List<RecordedRouteSummary>? _records;
  int _request = 0;

  Future<void> load() async {
    if (isClosed) return;
    final request = ++_request;
    emit(state.copyWith(loading: true, failed: false));
    try {
      final records = await _repository.getRecordedSummaries();
      if (isClosed || request != _request) return;
      _records = List.unmodifiable(records);
      _publish(loading: false, preserveSelection: true);
    } on Object catch (error, stack) {
      if (isClosed || request != _request) return;
      addError(error, stack);
      emit(state.copyWith(loading: false, failed: true));
    }
  }

  void selectPeriod(StatisticsPeriod period) {
    if (isClosed || state.period == period) return;
    _anchor = null;
    emit(state.copyWith(period: period));
    _publish();
  }

  void movePeriod(int direction) {
    if (isClosed ||
        (direction != -1 && direction != 1) ||
        state.period == StatisticsPeriod.allTime ||
        (direction == 1 && !state.canGoNext)) {
      return;
    }
    final date = state.data?.start;
    if (date == null) return;
    _anchor = state.period == StatisticsPeriod.week
        ? DateTime(date.year, date.month, date.day + 7 * direction)
        : DateTime(date.year, date.month + direction);
    _publish();
  }

  void selectBucket(int index) {
    if (isClosed || index < 0 || index >= (state.data?.buckets.length ?? 0)) {
      return;
    }
    emit(state.copyWith(selected: index));
  }

  void _publish({bool? loading, bool preserveSelection = false}) {
    final records = _records;
    if (records == null) return;
    final now = _clock();
    final data = RouteStatistics.calculate(
      records,
      period: state.period,
      anchor: _anchor ?? now,
      now: now,
    );
    var selected = data.buckets.lastIndexWhere((b) => b.totals.routes > 0);
    if (selected < 0) selected = 0;
    if (preserveSelection && state.data != null) {
      final date = state.data!.buckets[state.selected].start;
      final previous = data.buckets.indexWhere((b) => b.start == date);
      if (previous >= 0) selected = previous;
    }
    emit(
      state.copyWith(
        data: data,
        loading: loading,
        canGoNext:
            state.period != StatisticsPeriod.allTime &&
            !data.endExclusive.isAfter(now.toLocal()),
        selected: selected,
      ),
    );
  }
}
