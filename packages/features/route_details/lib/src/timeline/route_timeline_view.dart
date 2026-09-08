import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';

import '../photo_comment_sheet.dart';
import '../route_details_cubit.dart';
import 'route_timeline_entry.dart';

class RouteTimelineView extends StatelessWidget {
  const RouteTimelineView({
    super.key,
    required this.config,
    required this.onBack,
  });
  final MapTileConfig config;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Timeline'),
      leading: AppIconButton(
        tooltip: 'Back to route',
        icon: const Icon(FLucideIcons.arrowLeft),
        onPressed: onBack,
      ),
    ),
    body: SafeArea(
      top: false,
      child: BlocBuilder<RouteDetailsCubit, RouteDetailsState>(
        builder: (context, state) => switch (state) {
          RouteDetailsLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          RouteDetailsFailure(:final message) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message),
                const SizedBox(height: 12),
                AppButton(
                  onPressed: context.read<RouteDetailsCubit>().load,
                  prefix: const Icon(FLucideIcons.refreshCw),
                  label: 'Retry',
                ),
              ],
            ),
          ),
          RouteDetailsReady() => _Timeline(state: state, config: config),
        },
      ),
    ),
  );
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.state, required this.config});
  final RouteDetailsReady state;
  final MapTileConfig config;

  @override
  Widget build(BuildContext context) {
    final entries = RouteTimelineEntry.fromRoute(state.route, state.photos);
    final photos = [for (final entry in entries) ?entry.photo];
    final cubit = context.read<RouteDetailsCubit>();
    Future<String?> edit(BuildContext sheetContext, RoutePhotoDM photo) =>
        showPhotoCommentSheet(
          sheetContext,
          photo: photo,
          onSave: (comment) => cubit.updatePhotoComment(photo.id, comment),
        );
    final editable = state.route.status == Status.completed;
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = ((constraints.maxWidth - 720) / 2).clamp(
          16.0,
          double.infinity,
        );
        return CustomScrollView(
          key: const PageStorageKey('route-timeline'),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 24),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      RouteLabels.title(context, state.route),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    RouteStats(metrics: state.route.metrics),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 220,
                      child: RoutePreview(
                        route: state.route,
                        photos: photos,
                        config: config,
                      ),
                    ),
                    if (state.photoError case final error?) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              liveRegion: true,
                              child: Text(error),
                            ),
                          ),
                          AppIconButton(
                            tooltip: 'Retry photos',
                            icon: const Icon(FLucideIcons.refreshCw),
                            onPressed: cubit.loadPhotos,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 24),
              sliver: SliverList.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final photo = entry.photo;
                  return _TimelineEvent(
                    key: ValueKey(
                      photo == null
                          ? entry.kind.name
                          : 'timeline-photo-${photo.id}',
                    ),
                    entry: entry,
                    last: index == entries.length - 1,
                    onEdit: photo != null && editable && !state.photoBusy
                        ? () => unawaited(edit(context, photo))
                        : null,
                    editable: editable,
                    onOpen: photo == null
                        ? null
                        : () => unawaited(
                            showRoutePhotoViewer(
                              context,
                              photos: photos,
                              selected: photo,
                              onEditComment: editable ? edit : null,
                              onDelete: editable
                                  ? (photo) => cubit.deletePhoto(photo.id)
                                  : null,
                            ),
                          ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TimelineEvent extends StatelessWidget {
  const _TimelineEvent({
    super.key,
    required this.entry,
    required this.last,
    required this.editable,
    this.onOpen,
    this.onEdit,
  });
  final RouteTimelineEntry entry;
  final bool last;
  final bool editable;
  final VoidCallback? onOpen;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final photo = entry.photo;
    final point = entry.point;
    final latitude = photo?.latitude ?? point?.latitude;
    final longitude = photo?.longitude ?? point?.longitude;
    final (title, icon, color) = switch (entry.kind) {
      RouteTimelineKind.start => (
        'Start',
        FLucideIcons.flag,
        RecordedEndpointStyle.start.color,
      ),
      RouteTimelineKind.photo => ('Photo', FLucideIcons.camera, AppTheme.route),
      RouteTimelineKind.finish => (
        'Finish',
        RecordedEndpointStyle.end.icon,
        RecordedEndpointStyle.end.color,
      ),
    };
    return Stack(
      children: [
        if (!last)
          Positioned(
            top: 36,
            bottom: 0,
            left: 17,
            child: ColoredBox(
              color: colors.border,
              child: const SizedBox(width: 2),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(bottom: last ? 0 : 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox.square(
                dimension: 36,
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.time == null
                          ? 'Time unavailable'
                          : RouteLabels.date(context, entry.time!),
                      style: TextStyle(color: colors.mutedForeground),
                    ),
                    if (point != null && point.address.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(point.address),
                    ] else if (latitude != null && longitude != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
                        style: TextStyle(color: colors.mutedForeground),
                      ),
                    ],
                    if (photo != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Material(
                          child: InkWell(
                            onTap: onOpen,
                            child: Semantics(
                              button: true,
                              label: 'Open photo',
                              child: AspectRatio(
                                aspectRatio: 3 / 2,
                                child: RoutePhotoImage(photo: photo),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (photo.comment.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(photo.comment),
                      ],
                      if (editable) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: AppButton(
                            variant: FButtonVariant.ghost,
                            compact: true,
                            onPressed: onEdit,
                            prefix: const Icon(FLucideIcons.messageSquare),
                            label: photo.comment.isEmpty
                                ? 'Add comment'
                                : 'Edit comment',
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
