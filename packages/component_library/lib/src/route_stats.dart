import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

import 'route_labels.dart';
import 'live_route_stats.dart';
import 'theme/app_theme.dart';

class RouteStats extends StatelessWidget {
  const RouteStats({
    super.key,
    required this.metrics,
    this.live = false,
    this.vertical = false,
    this.columns,
  }) : assert(columns == null || (columns >= 1 && columns <= 4));

  final RouteMetrics metrics;
  final bool live;
  final bool vertical;
  final int? columns;

  static double minimumLiveWidth(BuildContext context, {required int columns}) {
    assert(columns == 1 || columns == 2 || columns == 4);
    return LiveRouteStats.minimumWidth(context, columns);
  }

  @override
  Widget build(BuildContext context) {
    if (live) {
      return LiveRouteStats(
        metrics: metrics,
        maxColumns: vertical ? 1 : columns ?? 4,
      );
    }
    final items = [
      (RouteLabels.distance(metrics.distance), 'Distance'),
      (RouteLabels.duration(metrics.duration), 'Duration'),
      (RouteLabels.speed(metrics.averageSpeed), 'Avg speed'),
      (RouteLabels.speed(metrics.maxSpeed), 'Max speed'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final minimum = 82 * MediaQuery.textScalerOf(context).scale(1);
        final availableColumns = (constraints.maxWidth / minimum).floor();
        final columnCount = vertical
            ? 1
            : availableColumns.clamp(1, columns ?? 4);
        final fontSize = vertical ? 19.0 : 22.0;
        final valueStyle = TextStyle(
          fontSize: fontSize,
          color: AppTheme.ink,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
        return Wrap(
          runSpacing: 12,
          children: [
            for (final (value, label) in items)
              SizedBox(
                width: constraints.maxWidth / columnCount,
                child: Semantics(
                  label: '$label: $value',
                  excludeSemantics: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      crossAxisAlignment: vertical
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.center,
                      children: [
                        Text(value, style: valueStyle),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
