import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'route_details_cubit.dart';
import 'photo_comment_sheet.dart';

class RoutePhotoGallery extends StatelessWidget {
  const RoutePhotoGallery({super.key, required this.state});
  final RouteDetailsReady state;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (state.photoError case final error?)
        Row(
          children: [
            Expanded(child: Text(error)),
            AppIconButton(
              tooltip: 'Retry photos',
              onPressed: context.read<RouteDetailsCubit>().loadPhotos,
              icon: const Icon(FLucideIcons.refreshCw),
            ),
          ],
        ),
      if (state.photos.isNotEmpty) ...[
        const SizedBox(height: 24),
        Text(
          'Photos (${state.photos.length})',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: state.photos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final photo = state.photos[index];
              return SizedBox.square(
                key: ValueKey('route-photo-${photo.id}'),
                dimension: 104,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Semantics(
                    button: true,
                    label: 'Open photo ${index + 1}',
                    child: GestureDetector(
                      onTap: () => unawaited(
                        showRoutePhotoViewer(
                          context,
                          photos: state.photos,
                          selected: photo,
                          onEditComment: state.route.status == Status.completed
                              ? (viewerContext, photo) => showPhotoCommentSheet(
                                  viewerContext,
                                  photo: photo,
                                  onSave: (comment) => context
                                      .read<RouteDetailsCubit>()
                                      .updatePhotoComment(photo.id, comment),
                                )
                              : null,
                          onDelete: state.route.status == Status.completed
                              ? (photo) => context
                                    .read<RouteDetailsCubit>()
                                    .deletePhoto(photo.id)
                              : null,
                        ),
                      ),
                      child: RoutePhotoImage(photo: photo),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ],
  );
}
