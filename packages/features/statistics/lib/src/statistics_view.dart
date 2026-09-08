import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
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
            child: Text('Statistics'),
          ),
          leading: AppIconButton(
            tooltip: 'Back to routes',
            icon: const Icon(FLucideIcons.arrowLeft),
            onPressed: onBack,
          ),
          actions: [
            AppIconButton(
              tooltip: 'About statistics',
              icon: const Icon(FLucideIcons.info),
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
            AppIconButton(
              tooltip: 'Refresh statistics',
              onPressed: state.loading ? null : cubit.load,
              icon: const Icon(FLucideIcons.refreshCw),
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
                            AppSegmentedControl<StatisticsPeriod>(
                              segments: const [
                                AppSegment(
                                  value: StatisticsPeriod.week,
                                  label: 'Week',
                                ),
                                AppSegment(
                                  value: StatisticsPeriod.month,
                                  label: 'Month',
                                ),
                                AppSegment(
                                  value: StatisticsPeriod.allTime,
                                  label: 'All time',
                                ),
                              ],
                              value: state.period,
                              onChanged: cubit.selectPeriod,
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
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: AppButton(
                                  compact: true,
                                  variant: FButtonVariant.ghost,
                                  onPressed: state.loading ? null : cubit.load,
                                  prefix: const Icon(FLucideIcons.refreshCw),
                                  label: 'Retry',
                                ),
                              ),
                            ],
                            if (data != null) ...[
                              const SizedBox(height: 16),
                              AppFadeSwitcher(
                                value: (
                                  state.period,
                                  data.start,
                                  data.endExclusive,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _PeriodNavigation(state: state),
                                    const SizedBox(height: 24),
                                    _Totals(totals: data.totals),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 28,
                                      ),
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
                                ),
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
          AppIconButton(
            tooltip: 'Previous period',
            onPressed: () => context.read<StatisticsCubit>().movePeriod(-1),
            icon: const Icon(FLucideIcons.chevronLeft),
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
          AppIconButton(
            tooltip: 'Next period',
            onPressed: state.canGoNext
                ? () => context.read<StatisticsCubit>().movePeriod(1)
                : null,
            icon: const Icon(FLucideIcons.chevronRight),
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
              FLucideIcons.route,
              Theme.of(context).colorScheme.primary,
            ),
            (
              'Recording time',
              RouteLabels.duration(totals.duration),
              FLucideIcons.clock,
              AppTheme.ink,
            ),
            (
              'Recordings',
              labels.formatDecimal(totals.routes),
              FLucideIcons.bookmark,
              AppTheme.coral,
            ),
            (
              'Active days',
              labels.formatDecimal(totals.activeDays),
              FLucideIcons.calendar,
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
        const Icon(FLucideIcons.route, size: 40, color: AppTheme.muted),
        const SizedBox(height: 12),
        Text(
          period == StatisticsPeriod.allTime
              ? 'No saved recordings yet'
              : 'No recordings in this period',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
        ),
        if (period != StatisticsPeriod.allTime) ...[
          const SizedBox(height: 8),
          AppButton(
            compact: true,
            variant: FButtonVariant.ghost,
            onPressed: () => context.read<StatisticsCubit>().selectPeriod(
              StatisticsPeriod.allTime,
            ),
            label: 'View all time',
          ),
        ],
      ],
    ),
  );
}
