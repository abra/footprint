import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';

import 'map_cubit.dart';
import 'map_state.dart';

class MapAppBar extends StatelessWidget {
  const MapAppBar({
    super.key,
    required this.onPageChange,
    this.onExploreRequested,
  });
  final VoidCallback onPageChange;
  final VoidCallback? onExploreRequested;

  @override
  Widget build(BuildContext context) => MapSurface(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < 320 ||
              (constraints.maxWidth < 360 &&
                  MediaQuery.textScalerOf(context).scale(14) > 20);
          final address = Row(
            children: [
              BlocSelector<MapCubit, MapState, bool>(
                selector: (state) => state.locationLoading,
                builder: (context, loading) => SizedBox.square(
                  dimension: 32,
                  child: loading
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: FCircularProgress(),
                        )
                      : const Icon(
                          FLucideIcons.mapPin,
                          color: AppTheme.success,
                          size: 20,
                          applyTextScaling: false,
                        ),
                ),
              ),
              Expanded(
                child: BlocSelector<MapCubit, MapState, String>(
                  selector: (state) => state.address,
                  builder: (context, address) => Text(
                    address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.ink,
                    ),
                  ),
                ),
              ),
            ],
          );
          final history = BlocSelector<MapCubit, MapState, bool>(
            selector: (state) => state.isRecording,
            builder: (context, recording) => AppIconButton(
              tooltip: 'Routes',
              onPressed: onPageChange,
              icon: Badge(
                isLabelVisible: recording,
                backgroundColor: AppTheme.coral,
                child: const Icon(FLucideIcons.list),
              ),
            ),
          );
          return BlocSelector<MapCubit, MapState, bool>(
            selector: (state) => state.isRecording || state.recordingBusy,
            builder: (context, busy) {
              final explore = !busy && onExploreRequested != null
                  ? AppButton(
                      onPressed: onExploreRequested,
                      label: 'Explore',
                      prefix: const Icon(FLucideIcons.compass, size: 18),
                      variant: FButtonVariant.secondary,
                      compact: true,
                    )
                  : null;
              return Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  Row(
                    children: [
                      Expanded(child: address),
                      if (!stacked && explore != null) ...[
                        const SizedBox(width: 8),
                        explore,
                        const SizedBox(width: 8),
                      ],
                      history,
                    ],
                  ),
                  if (stacked && explore != null)
                    Align(alignment: Alignment.centerLeft, child: explore),
                ],
              );
            },
          );
        },
      ),
    ),
  );
}
