import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';

import 'map_cubit.dart';
import 'map_state.dart';

class MapPhotoButton extends StatelessWidget {
  const MapPhotoButton({super.key});

  Future<void> _chooseSource(BuildContext context) async {
    final source = await showAppActionSheet<PhotoSource>(
      context,
      title: 'Add photo',
      actions: const [
        SheetAction(
          value: PhotoSource.camera,
          label: 'Take photo',
          icon: FLucideIcons.camera,
        ),
        SheetAction(
          value: PhotoSource.gallery,
          label: 'Choose photo',
          icon: FLucideIcons.image,
        ),
      ],
    );
    if (source != null && context.mounted) {
      await context.read<MapCubit>().capturePhoto(source);
    }
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<MapCubit, MapState>(
    buildWhen: (before, after) =>
        before.photoBusy != after.photoBusy ||
        before.recordingBusy != after.recordingBusy ||
        before.location != after.location,
    builder: (context, state) => MapSurface(
      child: AppIconButton(
        tooltip: 'Add route photo',
        onPressed:
            state.photoBusy || state.recordingBusy || state.location == null
            ? null
            : () => unawaited(_chooseSource(context)),
        icon: const Icon(FLucideIcons.camera, color: AppTheme.route),
      ),
    ),
  );
}

class MapPhotoError extends StatelessWidget {
  const MapPhotoError({super.key});
  @override
  Widget build(BuildContext context) => BlocBuilder<MapCubit, MapState>(
    builder: (context, state) {
      final error = state.photoError;
      if (error == null) return const SizedBox.shrink();
      final cubit = context.read<MapCubit>();
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: MapSurface(
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Semantics(
                    liveRegion: true,
                    child: Tooltip(
                      message: error,
                      child: Text(
                        error,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
              AppIconButton(
                tooltip: 'Retry photo save',
                onPressed: state.photoBusy ? null : cubit.retryPhotos,
                icon: const Icon(FLucideIcons.refreshCw),
              ),
              AppIconButton(
                tooltip: 'Discard pending photo',
                onPressed: state.photoBusy
                    ? null
                    : () async {
                        final confirmed = await showAppActionSheet<bool>(
                          context,
                          title: 'Discard pending photo?',
                          message:
                              'Saved photos and route points will be kept.',
                          actions: const [
                            SheetAction(
                              value: true,
                              label: 'Discard',
                              icon: FLucideIcons.x,
                              destructive: true,
                            ),
                          ],
                        );
                        if (confirmed == true && context.mounted) {
                          await cubit.discardPendingPhoto();
                        }
                      },
                icon: const Icon(FLucideIcons.x),
              ),
            ],
          ),
        ),
      );
    },
  );
}
