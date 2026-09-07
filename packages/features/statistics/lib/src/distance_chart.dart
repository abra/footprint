import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

class DistanceChart extends StatefulWidget {
  const DistanceChart({
    super.key,
    required this.data,
    required this.selected,
    required this.onSelected,
  });
  final RouteStatistics data;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  State<DistanceChart> createState() => _DistanceChartState();
}

class _DistanceChartState extends State<DistanceChart> {
  final _scroll = ScrollController();
  double? _slotWidth;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final labels = MaterialLocalizations.of(context);
    final selected = data.buckets[widget.selected];
    final maximum = data.buckets.fold(
      0.0,
      (max, bucket) => math.max(max, bucket.totals.distance),
    );
    final ceiling = math.max(1000.0, (maximum / 1000).ceilToDouble() * 1000);
    final color = Theme.of(context).colorScheme.primary;
    String dateLabel(DateTime date) => switch (data.interval) {
      StatisticsInterval.day => labels.formatFullDate(date),
      StatisticsInterval.month => labels.formatMonthYear(date),
      StatisticsInterval.year => labels.formatYear(date),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(switch (data.interval) {
          StatisticsInterval.day => 'Distance by day',
          StatisticsInterval.month => 'Distance by month',
          StatisticsInterval.year => 'Distance by year',
        }, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(
          RouteLabels.distance(ceiling),
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 12, color: AppTheme.muted),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final minimum = MediaQuery.textScalerOf(context).scale(1) > 1.4
                ? 72.0
                : 48.0;
            final width = math.max(
              minimum,
              constraints.maxWidth / data.buckets.length,
            );
            if (_slotWidth != width) {
              _slotWidth = width;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !_scroll.hasClients) return;
                final offset =
                    (widget.selected + 0.5) * width - constraints.maxWidth / 2;
                _scroll.jumpTo(
                  offset.clamp(0.0, _scroll.position.maxScrollExtent),
                );
              });
            }
            return Scrollbar(
              controller: _scroll,
              thumbVisibility:
                  width * data.buckets.length > constraints.maxWidth,
              child: SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (index, bucket) in data.buckets.indexed)
                      Semantics(
                        button: true,
                        onTap: () => widget.onSelected(index),
                        selected: index == widget.selected,
                        label:
                            '${dateLabel(bucket.start)}: ${RouteLabels.distance(bucket.totals.distance)}, '
                            '${bucket.totals.routes} recordings',
                        excludeSemantics: true,
                        child: SizedBox(
                          width: width,
                          child: InkWell(
                            key: ValueKey('statistics-bucket-$index'),
                            borderRadius: BorderRadius.circular(4),
                            onTap: () => widget.onSelected(index),
                            child: Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: 160,
                                  child: Stack(
                                    alignment: Alignment.bottomCenter,
                                    children: [
                                      const Positioned.fill(
                                        child: CustomPaint(
                                          painter: _GridPainter(),
                                        ),
                                      ),
                                      Container(
                                        width: math.min(28, width - 20),
                                        height: bucket.totals.distance == 0
                                            ? 2
                                            : math.max(
                                                3,
                                                160 *
                                                    bucket.totals.distance /
                                                    ceiling,
                                              ),
                                        decoration: BoxDecoration(
                                          color: bucket.totals.distance == 0
                                              ? AppTheme.border
                                              : index == widget.selected
                                              ? color
                                              : AppTheme.route,
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(4),
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  switch (data.interval) {
                                    StatisticsInterval.day =>
                                      '${labels.narrowWeekdays[bucket.start.weekday % 7]}\n${labels.formatDecimal(bucket.start.day)}',
                                    StatisticsInterval.month =>
                                      '${labels.formatDecimal(bucket.start.month)}\n${labels.formatYear(bucket.start)}',
                                    StatisticsInterval.year =>
                                      labels.formatYear(bucket.start),
                                  },
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: index == widget.selected
                                        ? color
                                        : AppTheme.muted,
                                    fontWeight: index == widget.selected
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateLabel(selected.start),
                key: const ValueKey('statistics-selected-date'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  Text(RouteLabels.distance(selected.totals.distance)),
                  Text(
                    '${selected.totals.routes} ${selected.totals.routes == 1 ? 'recording' : 'recordings'}',
                  ),
                  Text(RouteLabels.duration(selected.totals.duration)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.border
      ..strokeWidth = 1;
    for (final y in [0.5, size.height / 2, size.height - 0.5]) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}
