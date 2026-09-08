import 'dart:math' as math;

import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

import 'route_labels.dart';
import 'theme/app_theme.dart';

const _gap = 12.0;
const _unitGap = 4.0;
const _valueStyle = TextStyle(
  fontFamily: 'packages/component_library/RobotoCondensed',
  fontSize: 20,
  height: 1.2,
  color: AppTheme.ink,
  fontFeatures: [FontFeature.tabularFigures()],
);
const _unitStyle = TextStyle(fontSize: 12);
const _labelStyle = TextStyle(
  fontFamily: 'packages/component_library/RobotoCondensed',
  fontSize: 9,
  height: 1.2,
  color: AppTheme.muted,
);
const _labels = ['Current speed', 'Average speed', 'Distance', 'Duration'];

class LiveRouteStats extends StatefulWidget {
  const LiveRouteStats({
    super.key,
    required this.metrics,
    required this.maxColumns,
  });

  final RouteMetrics metrics;
  final int maxColumns;

  static double minimumWidth(BuildContext context, int columns) =>
      _StatsGeometry.measure(context).minimumWidth(columns);

  @override
  State<LiveRouteStats> createState() => _LiveRouteStatsState();
}

class _LiveRouteStatsState extends State<LiveRouteStats> {
  late _StatsGeometry _geometry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _geometry = _StatsGeometry.measure(context);
  }

  @override
  Widget build(BuildContext context) {
    final metrics = widget.metrics;
    final values = [
      RouteLabels.speedParts(metrics.currentSpeed),
      RouteLabels.speedParts(metrics.averageSpeed),
      RouteLabels.distanceParts(metrics.distance),
      (value: RouteLabels.duration(metrics.duration), unit: ''),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = [4, 2, 1].firstWhere(
          (count) =>
              count <= widget.maxColumns &&
              (count == 1 ||
                  _geometry.minimumWidth(count) <= constraints.maxWidth),
        );
        final widths = _geometry.columnWidths(columns);
        final spare =
            math.max(
              0.0,
              constraints.maxWidth - _geometry.minimumWidth(columns),
            ) /
            columns;
        final order = columns == 2 ? [0, 2, 1, 3] : [0, 1, 2, 3];
        return SizedBox(
          width: constraints.maxWidth,
          child: Wrap(
            alignment: columns == 4
                ? WrapAlignment.spaceBetween
                : WrapAlignment.start,
            spacing: _gap,
            runSpacing: 8,
            children: [
              for (final (index, item) in order.indexed)
                ConstrainedBox(
                  key: ValueKey('live-stat-$item'),
                  constraints: columns == 4
                      ? BoxConstraints(
                          // Speed digit changes must not redistribute the row.
                          minWidth: item < 2 ? widths[item] : 0,
                          maxWidth: widths[item],
                        )
                      : BoxConstraints.tightFor(
                          width: columns == 1
                              ? constraints.maxWidth
                              : widths[index % columns] + spare,
                        ),
                  child: Semantics(
                    label:
                        '${_labels[item]}: ${values[item].value}${values[item].unit.isEmpty ? '' : ' ${values[item].unit}'}',
                    excludeSemantics: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Flexible(
                              child: Text(
                                values[item].value,
                                key: ValueKey('live-stat-value-$item'),
                                style: _valueStyle,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (values[item].unit.isNotEmpty) ...[
                              const SizedBox(width: _unitGap),
                              Text(
                                values[item].unit,
                                key: ValueKey('live-stat-unit-$item'),
                                style: _valueStyle.merge(_unitStyle),
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _labels[item].toUpperCase(),
                          style: _labelStyle,
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StatsGeometry {
  const _StatsGeometry(this.widths);

  final List<double> widths;

  factory _StatsGeometry.measure(BuildContext context) {
    final inherited = DefaultTextStyle.of(context).style;
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
    );
    double measure(InlineSpan text) {
      painter.text = text;
      painter.layout();
      return painter.width;
    }

    // Fixed ranges choose the row count without measuring changing readings.
    const samples = [
      (value: '888.8', unit: 'km/h'),
      (value: '888.8', unit: 'km/h'),
      (value: '8888.8', unit: 'km'),
      (value: '888:88:88', unit: ''),
    ];
    try {
      return _StatsGeometry([
        for (final (index, sample) in samples.indexed)
          math.max(
            measure(
                  TextSpan(
                    style: inherited.merge(_valueStyle),
                    text: sample.value,
                  ),
                ) +
                (sample.unit.isEmpty ? 0 : _unitGap) +
                measure(
                  TextSpan(
                    style: inherited.merge(_valueStyle).merge(_unitStyle),
                    text: sample.unit,
                  ),
                ),
            measure(
              TextSpan(
                style: inherited.merge(_labelStyle),
                text: _labels[index].toUpperCase(),
              ),
            ),
          ),
      ]);
    } finally {
      painter.dispose();
    }
  }

  List<double> columnWidths(int columns) => switch (columns) {
    4 => widths,
    2 => [math.max(widths[0], widths[1]), math.max(widths[2], widths[3])],
    _ => [widths.reduce(math.max)],
  };

  double minimumWidth(int columns) =>
      columnWidths(columns).fold(0.0, (sum, width) => sum + width) +
      _gap * (columns - 1);
}
