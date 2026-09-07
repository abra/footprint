import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

import 'route_speed_chart.dart';

class RecordingStatsPanel extends StatelessWidget {
  const RecordingStatsPanel({
    super.key,
    required this.metrics,
    required this.expanded,
    required this.onToggle,
  });

  final RouteMetrics metrics;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (!expanded) return RouteStats(metrics: metrics, live: true);
            final stats = RouteStats(metrics: metrics, live: true, columns: 2);
            final chart = SizedBox(
              height: 72,
              child: RouteSpeedChart(samples: metrics.speedHistory),
            );
            final statsWidth = RouteStats.minimumLiveWidth(context, columns: 2);
            if (constraints.maxWidth < statsWidth + 16 + 128) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [chart, const SizedBox(height: 12), stats],
              );
            }
            return Row(
              children: [
                Expanded(child: chart),
                const SizedBox(width: 16),
                SizedBox(width: statsWidth, child: stats),
              ],
            );
          },
        ),
      ),
    );
    return MapSurface(
      child: Semantics(
        label: 'Recording statistics',
        button: true,
        expanded: expanded,
        child: InkWell(
          key: const ValueKey('recording-stats-panel'),
          customBorder: AppTheme.controlShape,
          onTap: onToggle,
          child: MediaQuery.disableAnimationsOf(context)
              ? content
              : AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.bottomCenter,
                  child: content,
                ),
        ),
      ),
    );
  }
}
