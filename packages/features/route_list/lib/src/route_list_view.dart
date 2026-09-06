import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'route_list_cubit.dart';

class RouteListView extends StatelessWidget {
  const RouteListView({super.key, required this.onMapRequested});
  final VoidCallback onMapRequested;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Routes'),
      leading: IconButton(
        tooltip: 'Back to map',
        onPressed: onMapRequested,
        icon: const Icon(Icons.arrow_back),
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: context.read<RouteListCubit>().load,
        ),
      ],
    ),
    body: BlocBuilder<RouteListCubit, RouteListState>(
      builder: (context, state) => switch (state) {
        RouteListLoading() => const Center(child: CircularProgressIndicator()),
        RouteListFailure() => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Routes could not be loaded.'),
              TextButton(
                onPressed: context.read<RouteListCubit>().load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        RouteListLoaded(:final routes) when routes.isEmpty => const Center(
          child: Text('No recorded routes'),
        ),
        RouteListLoaded(:final routes) => RefreshIndicator(
          onRefresh: context.read<RouteListCubit>().load,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: routes.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final route = routes[index];
              final date = route.startTime.toLocal();
              final localizations = MaterialLocalizations.of(context);
              return ListTile(
                leading: Icon(
                  route.status == Status.active
                      ? Icons.fiber_manual_record
                      : Icons.route,
                ),
                title: Text(localizations.formatMediumDate(date)),
                subtitle: Text(
                  localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date)),
                ),
                trailing: Text(
                  route.status == Status.active ? 'Recording' : 'Saved',
                ),
              );
            },
          ),
        ),
      },
    ),
  );
}
