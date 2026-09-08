import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_theme.dart';

/// A recorded endpoint anchored at the glyph's tip, rather than its center.
class RecordedRouteMarker extends Marker {
  RecordedRouteMarker.start({required LatLng point, double opacity = 1})
    : this._(
        point: point,
        style: RecordedEndpointStyle.start,
        opacity: opacity,
      );

  RecordedRouteMarker.end({required LatLng point, double opacity = 1})
    : this._(point: point, style: RecordedEndpointStyle.end, opacity: opacity);

  RecordedRouteMarker._({
    required super.point,
    required RecordedEndpointStyle style,
    required double opacity,
  }) : assert(opacity >= 0 && opacity <= 1),
       super(
         width: 32,
         height: 32,
         // Material glyphs use a 24px grid, scaled to 30px with 1px padding.
         alignment: Marker.computePixelAlignment(
           width: 32,
           height: 32,
           left: 1 + style.tip.dx * 30 / 24,
           top: 1 + style.tip.dy * 30 / 24,
         ),
         rotate: true,
         child: Tooltip(
           message: style.label,
           child: Icon(
             style.icon,
             color: style.color.withValues(alpha: opacity),
             size: 30,
             applyTextScaling: false,
           ),
         ),
       );
}

enum RecordedEndpointStyle {
  start(Icons.flag, AppTheme.coral, 'Route start', Offset(6, 21)),
  end(Icons.location_on, AppTheme.success, 'Route end', Offset(12, 22));

  const RecordedEndpointStyle(this.icon, this.color, this.label, this.tip);
  final IconData icon;
  final Color color;
  final String label;
  // Coordinates in the original Material glyph's 24px grid.
  final Offset tip;
}
