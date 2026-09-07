import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'distance_chart.dart';
import 'statistics_cubit.dart';

class StatisticsView extends StatelessWidget {
  const StatisticsView({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<StatisticsCubit, StatisticsState>(
    builder: (context, state) {
      final cubit = context.read<StatisticsCubit>();
      final data = state.data;
      return Scaffold(
        appBar: AppBar(
          title: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('STATISTICS'),
          ),
          leading: IconButton(
            tooltip: 'Back to routes',
            icon: const Icon(Icons.arrow_back),
            onPressed: onBack,
          ),
          actions: [
            IconButton(
              tooltip: 'About statistics',
              icon: const Icon(Icons.info_outline),
              onPressed: () => showAppActionSheet<void>(
                context,
                title: 'About statistics',
                message:
                    'Only saved recordings are counted. Active recordings '
                    'are excluded.\n\nDistance uses your recorded GPS track. '
                    'Recording time includes stops and is not moving time. '
                    'All activity types are included.\n\nEach recording belongs '
                    'to its start date in your current local timezone, even if '
                    'it ends the next day. Weeks start on Monday.\n\nDeleting '
                    'a recording removes it from these statistics.',
                actions: const [],
                cancelLabel: 'Done',
              ),
            ),
            IconButton(
              tooltip: 'Refresh statistics',
              onPressed: state.loading ? null : cubit.load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              SizedBox(
                height: 3,
                child: state.loading
                    ? const LinearProgressIndicator()
                    : const SizedBox.expand(),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: cubit.load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SegmentedButton<StatisticsPeriod>(
                              showSelectedIcon: false,
                              expandedInsets: EdgeInsets.zero,
                              style: SegmentedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 4,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              segments: const [
                                ButtonSegment(
                                  value: StatisticsPeriod.week,
                                  label: Text('Week'),
                                ),
                                ButtonSegment(
                                  value: StatisticsPeriod.month,
                                  label: Text('Month'),
                                ),
                                ButtonSegment(
                                  value: StatisticsPeriod.allTime,
                                  label: Text(
                                    'All time',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                              selected: {state.period},
                              onSelectionChanged: (value) =>
                                  cubit.selectPeriod(value.single),
                            ),
                            if (state.failed) ...[
                              const SizedBox(height: 20),
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  data == null
                                      ? 'Statistics could not be loaded.'
                                      : 'Statistics could not be refreshed.',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: state.loading ? null : cubit.load,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                ),
                              ),
                            ],
                            if (data != null) ...[
                              const SizedBox(height: 16),
                              _PeriodNavigation(state: state),
                              const SizedBox(height: 24),
                              _Totals(totals: data.totals),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 28),
                                child: Divider(height: 1),
                              ),
                              if (data.totals.routes == 0)
                                _EmptyPeriod(period: state.period)
                              else
                                DistanceChart(
                                  key: ValueKey((
                                    state.period,
                                    data.start,
                                    data.interval,
                                  )),
                                  data: data,
                                  selected: state.selected,
                                  onSelected: cubit.selectBucket,
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _PeriodNavigation extends StatelessWidget {
  const _PeriodNavigation({required this.state});
  final StatisticsState state;

  @override
  Widget build(BuildContext context) {
    final data = state.data!;
    final labels = MaterialLocalizations.of(context);
    final last = DateTime(
      data.endExclusive.year,
      data.endExclusive.month,
      data.endExclusive.day - 1,
    );
    final label = state.period == StatisticsPeriod.month
        ? labels.formatMonthYear(data.start)
        : '${labels.formatShortDate(data.start)} - ${labels.formatShortDate(last)}';
    return Row(
      children: [
        if (state.period != StatisticsPeriod.allTime)
          IconButton(
            tooltip: 'Previous period',
            onPressed: () => context.read<StatisticsCubit>().movePeriod(-1),
            icon: const Icon(Icons.chevron_left),
          ),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        if (state.period != StatisticsPeriod.allTime)
          IconButton(
            tooltip: 'Next period',
            onPressed: state.canGoNext
                ? () => context.read<StatisticsCubit>().movePeriod(1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
      ],
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.totals});
  final StatisticsTotals totals;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth >= 640 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.1
          ? 4
          : constraints.maxWidth >= 280 &&
                MediaQuery.textScalerOf(context).scale(1) <= 1.4
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * 24) / columns;
      final labels = MaterialLocalizations.of(context);
      return Wrap(
        spacing: 24,
        runSpacing: 28,
        children: [
          for (final (label, value, icon, color) in [
            (
              'Distance',
              RouteLabels.distance(totals.distance),
              Icons.route_outlined,
              Theme.of(context).colorScheme.primary,
            ),
            (
              'Recording time',
              RouteLabels.duration(totals.duration),
              Icons.schedule_outlined,
              AppTheme.ink,
            ),
            (
              'Recordings',
              labels.formatDecimal(totals.routes),
              Icons.bookmark_border,
              AppTheme.coral,
            ),
            (
              'Active days',
              labels.formatDecimal(totals.activeDays),
              Icons.calendar_today_outlined,
              AppTheme.appColors.darkCyan,
            ),
          ])
            SizedBox(
              width: width,
              child: Semantics(
                label: '$label: $value',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: color, size: 22),
                    const SizedBox(height: 8),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _EmptyPeriod extends StatelessWidget {
  const _EmptyPeriod({required this.period});
  final StatisticsPeriod period;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        const Icon(Icons.route_outlined, size: 40, color: AppTheme.muted),
        const SizedBox(height: 12),
        Text(
          period == StatisticsPeriod.allTime
              ? 'No saved recordings yet'
              : 'No recordings in this period',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
        ),
        if (period != StatisticsPeriod.allTime)
          TextButton(
            onPressed: () => context.read<StatisticsCubit>().selectPeriod(
              StatisticsPeriod.allTime,
            ),
            child: const Text('View all time'),
          ),
      ],
    ),
  );
}
