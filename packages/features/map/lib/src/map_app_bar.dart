import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'map_cubit.dart';
import 'map_state.dart';

class MapAppBar extends StatelessWidget {
  const MapAppBar({super.key, required this.onPageChange});
  final VoidCallback onPageChange;

  @override
  Widget build(BuildContext context) => MapSurface(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          BlocSelector<MapCubit, MapState, bool>(
            selector: (state) => state.locationLoading,
            builder: (context, loading) => SizedBox.square(
              dimension: 44,
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.location_on,
                      color: AppTheme.success,
                      size: 30,
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
                style: const TextStyle(fontSize: 17, color: AppTheme.ink),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 28, color: AppTheme.border),
          BlocSelector<MapCubit, MapState, bool>(
            selector: (state) => state.isRecording,
            builder: (context, recording) => IconButton(
              tooltip: 'Routes',
              onPressed: onPageChange,
              icon: Badge(
                isLabelVisible: recording,
                backgroundColor: AppTheme.coral,
                child: const Icon(Icons.format_list_bulleted, size: 28),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
