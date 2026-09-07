import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statistics/src/statistics_cubit.dart';

import 'fakes.dart';

void main() {
  late StatisticsRepositoryFake repository;
  late StatisticsCubit cubit;
  setUp(() {
    repository = StatisticsRepositoryFake();
    cubit = StatisticsCubit(repository: repository, clock: statisticsNow);
  });
  tearDown(() => cubit.close());

  test(
    'loads a snapshot and switches periods without reading storage again',
    () async {
      final pending = cubit.load();
      expect(cubit.state.loading, isTrue);
      await pending;
      expect(cubit.state.data!.totals.routes, 5);
      expect(cubit.state.selected, 5);
      cubit.selectPeriod(StatisticsPeriod.month);
      expect(cubit.state.data!.buckets, hasLength(30));
      cubit.selectPeriod(StatisticsPeriod.allTime);
      expect(cubit.state.data!.buckets, hasLength(1));
      expect(repository.reads, 1);
    },
  );

  test(
    'period navigation cannot enter the future and handles month lengths',
    () async {
      await cubit.load();
      final current = cubit.state.data;
      cubit.movePeriod(1);
      expect(cubit.state.data, same(current));
      cubit.movePeriod(-1);
      expect(cubit.state.data!.start, DateTime(2026, 8, 31));
      expect(cubit.state.canGoNext, isTrue);
      cubit.movePeriod(1);
      expect(cubit.state.data, current);
      cubit.selectPeriod(StatisticsPeriod.month);
      cubit.movePeriod(-1);
      expect(cubit.state.data!.buckets, hasLength(31));
      cubit.movePeriod(1);
      expect(cubit.state.data!.buckets, hasLength(30));
      cubit.selectPeriod(StatisticsPeriod.allTime);
      final all = cubit.state;
      cubit.movePeriod(-1);
      cubit.movePeriod(0);
      expect(cubit.state, same(all));
    },
  );

  test(
    'period selected while loading is respected when the request completes',
    () async {
      final gate = Completer<List<RecordedRouteSummary>>();
      repository.response = () => gate.future;
      final pending = cubit.load();
      cubit.selectPeriod(StatisticsPeriod.month);
      gate.complete(statisticsRecords());
      await pending;
      expect(cubit.state.period, StatisticsPeriod.month);
      expect(cubit.state.data!.buckets, hasLength(30));
    },
  );

  test(
    'refresh failures retain data, and retry incorporates deletions',
    () async {
      await cubit.load();
      cubit.selectBucket(1);
      final before = cubit.state.data;
      repository.response = () async => throw StateError('Unavailable');
      await cubit.load();
      expect(cubit.state.failed, isTrue);
      expect(cubit.state.data, same(before));
      expect(cubit.state.selected, 1);
      repository.response = () async => [];
      await cubit.load();
      expect(cubit.state.failed, isFalse);
      expect(cubit.state.data!.totals.routes, 0);
      expect(cubit.state.selected, 1);
    },
  );

  test('initial failure is not presented as empty activity', () async {
    repository.response = () async => throw StateError('Unavailable');
    await cubit.load();
    expect(cubit.state.failed, isTrue);
    expect(cubit.state.data, isNull);
    expect(cubit.state.loading, isFalse);
  });

  for (final fail in [false, true]) {
    test(
      'stale ${fail ? 'failure' : 'success'} cannot replace a newer result',
      () async {
        final gate = Completer<List<RecordedRouteSummary>>();
        repository.response = () => gate.future;
        final stale = cubit.load();
        repository.response = () async => [];
        await cubit.load();
        fail
            ? gate.completeError(StateError('Late'))
            : gate.complete(statisticsRecords());
        await stale;
        expect(cubit.state.data!.totals.routes, 0);
        expect(cubit.state.failed, isFalse);
      },
    );
  }

  test('close rejects late results, selections and new requests', () async {
    final gate = Completer<List<RecordedRouteSummary>>();
    repository.response = () => gate.future;
    final pending = cubit.load();
    await cubit.close();
    gate.complete(statisticsRecords());
    await pending;
    await cubit.load();
    cubit.selectPeriod(StatisticsPeriod.month);
    cubit.movePeriod(-1);
    cubit.selectBucket(1);
    expect(repository.reads, 1);
    expect(cubit.state.data, isNull);
  });

  test('refresh rolls the current period forward while historical periods stay pinned', () async {
    var now = DateTime(2026, 9, 13, 23, 59);
    final clocked = StatisticsCubit(repository: repository, clock: () => now);
    addTearDown(clocked.close);
    await clocked.load();
    now = DateTime(2026, 9, 14);
    await clocked.load();
    expect(clocked.state.data!.start, DateTime(2026, 9, 14));
    clocked.movePeriod(-1);
    now = DateTime(2026, 9, 21);
    await clocked.load();
    expect(clocked.state.data!.start, DateTime(2026, 9, 7));
  });

  test('invalid bucket selections do not change the selected day', () async {
    await cubit.load();
    cubit.selectBucket(-1);
    cubit.selectBucket(7);
    expect(cubit.state.selected, 5);
    cubit.selectBucket(0);
    expect(cubit.state.selected, 0);
  });
}
