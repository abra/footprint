import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'map_cubit.dart';
import 'map_state.dart';

class MapPhotoButton extends StatelessWidget {
  const MapPhotoButton({super.key});

  Future<void> _chooseSource(BuildContext context) async {
    final source = await showModalBottomSheet<PhotoSource>(
      context: context,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take photo'),
                onTap: () => Navigator.pop(context, PhotoSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose photo'),
                onTap: () => Navigator.pop(context, PhotoSource.gallery),
              ),
            ],
          ),
        ),
      ),
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
      child: IconButton(
        tooltip: 'Add route photo',
        onPressed:
            state.photoBusy || state.recordingBusy || state.location == null
            ? null
            : () => unawaited(_chooseSource(context)),
        icon: state.photoBusy
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.camera_alt, color: AppTheme.route, size: 28),
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
              IconButton(
                tooltip: 'Retry photo save',
                onPressed: state.photoBusy ? null : cubit.retryPhotos,
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: 'Discard pending photo',
                onPressed: state.photoBusy
                    ? null
                    : () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            scrollable: true,
                            title: const Text('Discard pending photo?'),
                            content: const Text(
                              'Saved photos and route points will be kept.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Discard'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true && context.mounted) {
                          await cubit.discardPendingPhoto();
                        }
                      },
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      );
    },
  );
}
