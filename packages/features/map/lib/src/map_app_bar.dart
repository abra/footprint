import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'map_cubit.dart';
import 'map_state.dart';

class MapAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MapAppBar({super.key, required this.onPageChange});

  final VoidCallback onPageChange;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    title: BlocSelector<MapCubit, MapState, String>(
      selector: (state) => state.address,
      builder: (context, address) => Text(
        address,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    ),
    actions: [
      IconButton(
        tooltip: 'Routes',
        onPressed: onPageChange,
        icon: const Icon(Icons.route),
      ),
    ],
  );
}
