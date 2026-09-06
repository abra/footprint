import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'route_list_cubit.dart';

class RouteListView extends StatelessWidget {
  const RouteListView({
    super.key,
    required this.onMapRequested,
    this.config = const MapTileConfig(),
    this.onRouteRequested,
  });
  final VoidCallback onMapRequested;
  final MapTileConfig config;
  final Future<void> Function(int)? onRouteRequested;

  Future<void> _open(BuildContext context, RouteDM route) async {
    if (onRouteRequested == null) return;
    await onRouteRequested!(route.id);
    if (context.mounted) await context.read<RouteListCubit>().load();
  }

  Future<void> _delete(BuildContext context, RouteDM route) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Delete route?'),
        content: Text(RouteLabels.title(context, route)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<RouteListCubit>().delete(route);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('ROUTES'),
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
        BlocBuilder<RouteListCubit, RouteListState>(
          builder: (context, state) => PopupMenuButton<RouteSort>(
            tooltip: 'Sort routes',
            icon: const Icon(Icons.sort),
            initialValue: context.read<RouteListCubit>().sort,
            onSelected: context.read<RouteListCubit>().sortBy,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: RouteSort.newest,
                child: Text('Newest first'),
              ),
              PopupMenuItem(
                value: RouteSort.oldest,
                child: Text('Oldest first'),
              ),
              PopupMenuItem(value: RouteSort.name, child: Text('Name')),
            ],
          ),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: _RouteSearch(),
          ),
          Expanded(
            child: BlocBuilder<RouteListCubit, RouteListState>(
              builder: (context, state) => switch (state) {
                RouteListLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
                RouteListFailure() => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Routes could not be loaded.'),
                      TextButton.icon(
                        onPressed: context.read<RouteListCubit>().load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                RouteListLoaded(:final routes) when routes.isEmpty => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.route_outlined,
                        size: 44,
                        color: AppTheme.muted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.read<RouteListCubit>().query.isEmpty
                            ? 'No recorded routes'
                            : 'No matching routes',
                      ),
                    ],
                  ),
                ),
                RouteListLoaded(:final routes) => RefreshIndicator(
                  onRefresh: context.read<RouteListCubit>().load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: routes.length + 1,
                    separatorBuilder: (_, index) => const SizedBox(height: 28),
                    itemBuilder: (context, index) {
                      if (index == routes.length) {
                        return Column(
                          children: [
                            if (state.error case final error?)
                              Text(
                                error,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            if (state.hasMore)
                              TextButton.icon(
                                onPressed: state.loadingMore
                                    ? null
                                    : context.read<RouteListCubit>().loadMore,
                                icon: state.loadingMore
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.expand_more),
                                label: const Text('More routes'),
                              ),
                          ],
                        );
                      }
                      final route = routes[index];
                      return _RouteEntry(
                        key: ValueKey(route.id),
                        route: route,
                        config: config,
                        deleting: state.deletingId == route.id,
                        onOpen: onRouteRequested == null
                            ? null
                            : () => unawaited(_open(context, route)),
                        onDelete:
                            state.deletingId != null ||
                                route.status == Status.active
                            ? null
                            : () => unawaited(_delete(context, route)),
                      );
                    },
                  ),
                ),
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _RouteSearch extends StatefulWidget {
  const _RouteSearch();
  @override
  State<_RouteSearch> createState() => _RouteSearchState();
}

class _RouteSearchState extends State<_RouteSearch> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    onChanged: context.read<RouteListCubit>().search,
    onSubmitted: (_) => unawaited(context.read<RouteListCubit>().load()),
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: 'Search routes',
      prefixIcon: const Icon(Icons.search),
      suffixIcon: IconButton(
        tooltip: 'Clear search',
        icon: const Icon(Icons.close),
        onPressed: () {
          _controller.clear();
          context.read<RouteListCubit>().search('');
        },
      ),
    ),
  );
}

class _RouteEntry extends StatelessWidget {
  const _RouteEntry({
    super.key,
    required this.route,
    required this.config,
    required this.deleting,
    this.onOpen,
    this.onDelete,
  });
  final RouteDM route;
  final MapTileConfig config;
  final bool deleting;
  final VoidCallback? onOpen;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      RouteLabels.title(context, route),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Created ${RouteLabels.date(context, route.startTime)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.muted,
                      ),
                    ),
                    if (route.status == Status.active)
                      const Text(
                        'Recording',
                        style: TextStyle(color: AppTheme.coral),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (deleting)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (onOpen != null || onDelete != null)
            PopupMenuButton<String>(
              tooltip: 'Route actions',
              icon: const Icon(Icons.more_vert),
              onSelected: (action) =>
                  action == 'delete' ? onDelete?.call() : onOpen?.call(),
              itemBuilder: (_) => [
                if (onOpen != null)
                  PopupMenuItem(
                    value: 'open',
                    child: Text(
                      route.status == Status.active
                          ? 'View route'
                          : 'View or rename',
                    ),
                  ),
                if (onDelete != null)
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
      const SizedBox(height: 8),
      LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < 340 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.3;
          final preview = AspectRatio(
            aspectRatio: stacked ? 1.55 : 1.4,
            child: RoutePreview(route: route, config: config, onTap: onOpen),
          );
          if (stacked) {
            return Column(
              children: [
                preview,
                const SizedBox(height: 16),
                RouteStats(metrics: route.metrics),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: preview),
              const SizedBox(width: 16),
              SizedBox(
                width: 96,
                child: RouteStats(metrics: route.metrics, vertical: true),
              ),
            ],
          );
        },
      ),
    ],
  );
}
