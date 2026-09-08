import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:route_snapshots/route_snapshots.dart';
import 'package:url_launcher/url_launcher.dart';

import 'route_thumbnail_cubit.dart';

class RouteThumbnail extends StatelessWidget {
  const RouteThumbnail({
    super.key,
    required this.route,
    required this.snapshots,
    required this.config,
    this.onTap,
  });
  final RouteDM route;
  final RouteSnapshotRepository snapshots;
  final MapTileConfig config;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => BlocProvider(
    key: ValueKey(route),
    create: (_) =>
        RouteThumbnailCubit(route: route, snapshots: snapshots)..load(),
    child: _ThumbnailView(config: config, onTap: onTap),
  );
}

class _ThumbnailView extends StatelessWidget {
  const _ThumbnailView({required this.config, this.onTap});
  final MapTileConfig config;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<RouteThumbnailCubit, RouteThumbnailState>(
        builder: (context, state) => AspectRatio(
          aspectRatio: RouteSnapshotScene.aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Semantics(
                  label: 'Recorded route preview',
                  button: onTap != null,
                  child: GestureDetector(
                    onTap: onTap,
                    behavior: HitTestBehavior.opaque,
                    child: RepaintBoundary(
                      child: state.image != null
                          ? Image.memory(
                              state.image!,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                              excludeFromSemantics: true,
                              frameBuilder: (_, child, frame, _) =>
                                  frame == null
                                  ? CustomPaint(
                                      painter: RouteSnapshotPlaceholder(
                                        state.scene,
                                      ),
                                    )
                                  : child,
                              errorBuilder: (_, _, _) => CustomPaint(
                                painter: RouteSnapshotPlaceholder(state.scene),
                              ),
                            )
                          : CustomPaint(
                              painter: RouteSnapshotPlaceholder(state.scene),
                            ),
                    ),
                  ),
                ),
                if (state.scene.points.isEmpty)
                  const IgnorePointer(
                    child: Center(child: Text('No route points')),
                  ),
                if (state.image != null)
                  Positioned(
                    right: 4,
                    left: 4,
                    bottom: 4,
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Semantics(
                        link: true,
                        child: GestureDetector(
                          onTap: () => launchUrl(
                            Uri.parse(config.attributionUrl),
                            mode: LaunchMode.externalApplication,
                          ),
                          child: ColoredBox(
                            color: Colors.white.withValues(alpha: 0.9),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Text(
                                '\u00a9 ${config.attribution}',
                                textScaler: TextScaler.noScaling,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.ink,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (state.failed)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: MapSurface(
                      child: AppIconButton(
                        tooltip: 'Retry route map',
                        icon: const Icon(FLucideIcons.cloudOff),
                        onPressed: context.read<RouteThumbnailCubit>().load,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}
