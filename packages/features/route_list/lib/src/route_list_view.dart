import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'route_list_cubit.dart';

class RouteListView extends StatelessWidget {
  const RouteListView({
    super.key,
    required this.onMapRequested,
    required this.thumbnailBuilder,
    this.onRouteRequested,
    this.onStatisticsRequested,
  });
  final VoidCallback onMapRequested;
  final Widget Function(RouteDM route, VoidCallback? onTap) thumbnailBuilder;
  final Future<void> Function(int)? onRouteRequested;
  final VoidCallback? onStatisticsRequested;

  Future<void> _open(BuildContext context, RouteDM route) async {
    if (onRouteRequested == null) return;
    await onRouteRequested!(route.id);
    if (context.mounted) await context.read<RouteListCubit>().load();
  }

  Future<void> _delete(BuildContext context, RouteDM route) async {
    final confirmed = await showAppActionSheet<bool>(
      context,
      title: 'Delete route?',
      message:
          '${RouteLabels.title(context, route)}\nExplored areas and achievements will be kept.',
      actions: const [
        SheetAction(
          value: true,
          label: 'Delete',
          icon: FLucideIcons.trash2,
          destructive: true,
        ),
      ],
    );
    if (confirmed == true && context.mounted) {
      await context.read<RouteListCubit>().delete(route);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Routes'),
      leading: AppIconButton(
        tooltip: 'Back to map',
        onPressed: onMapRequested,
        icon: const Icon(FLucideIcons.arrowLeft),
      ),
      actions: [
        if (onStatisticsRequested != null)
          AppIconButton(
            tooltip: 'Statistics',
            icon: const Icon(FLucideIcons.chartNoAxesColumn),
            onPressed: onStatisticsRequested,
          ),
        AppIconButton(
          tooltip: 'Refresh',
          icon: const Icon(FLucideIcons.refreshCw),
          onPressed: context.read<RouteListCubit>().load,
        ),
        BlocBuilder<RouteListCubit, RouteListState>(
          builder: (context, state) => AppIconButton(
            tooltip: 'Sort routes',
            icon: const Icon(FLucideIcons.listFilter),
            onPressed: () async {
              final cubit = context.read<RouteListCubit>();
              final sort = await showAppActionSheet<RouteSort>(
                context,
                title: 'Sort routes',
                actions: [
                  SheetAction(
                    value: RouteSort.newest,
                    label: 'Newest first',
                    icon: FLucideIcons.arrowDown,
                    selected: cubit.sort == RouteSort.newest,
                  ),
                  SheetAction(
                    value: RouteSort.oldest,
                    label: 'Oldest first',
                    icon: FLucideIcons.arrowUp,
                    selected: cubit.sort == RouteSort.oldest,
                  ),
                  SheetAction(
                    value: RouteSort.name,
                    label: 'Name',
                    icon: FLucideIcons.arrowDownAZ,
                    selected: cubit.sort == RouteSort.name,
                  ),
                ],
              );
              if (context.mounted && sort != null) cubit.sortBy(sort);
            },
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
                      const SizedBox(height: 8),
                      AppButton(
                        compact: true,
                        variant: FButtonVariant.ghost,
                        onPressed: context.read<RouteListCubit>().load,
                        prefix: const Icon(FLucideIcons.refreshCw),
                        label: 'Retry',
                      ),
                    ],
                  ),
                ),
                RouteListLoaded(:final routes) when routes.isEmpty => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        FLucideIcons.route,
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
                          spacing: 8,
                          children: [
                            if (state.error case final error?)
                              Text(
                                error,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            if (state.hasMore)
                              AppButton(
                                compact: true,
                                variant: FButtonVariant.ghost,
                                onPressed: state.loadingMore
                                    ? null
                                    : context.read<RouteListCubit>().loadMore,
                                prefix: state.loadingMore
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(FLucideIcons.chevronDown),
                                label: 'More routes',
                              ),
                          ],
                        );
                      }
                      final route = routes[index];
                      return _RouteEntry(
                        key: ValueKey(route.id),
                        route: route,
                        thumbnail: thumbnailBuilder(
                          route,
                          onRouteRequested == null
                              ? null
                              : () => unawaited(_open(context, route)),
                        ),
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
  Widget build(BuildContext context) => FTextField(
    control: FTextFieldControl.managed(
      controller: _controller,
      onChange: (value) {
        final cubit = context.read<RouteListCubit>();
        if (value.text != cubit.query) cubit.search(value.text);
      },
    ),
    onSubmit: (_) => unawaited(context.read<RouteListCubit>().load()),
    textInputAction: TextInputAction.search,
    hint: 'Search routes',
    prefixBuilder: (_, _, _) => const Padding(
      padding: EdgeInsets.only(left: 12),
      child: Icon(FLucideIcons.search, size: 20),
    ),
    suffixBuilder: (_, _, _) => AppIconButton(
      tooltip: 'Clear search',
      icon: const Icon(FLucideIcons.x),
      onPressed: () {
        _controller.clear();
        context.read<RouteListCubit>().search('');
      },
    ),
  );
}

class _RouteEntry extends StatelessWidget {
  const _RouteEntry({
    super.key,
    required this.route,
    required this.thumbnail,
    required this.deleting,
    this.onOpen,
    this.onDelete,
  });
  final RouteDM route;
  final Widget thumbnail;
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
            child: FTappable(
              style: const .delta(motion: FTappableMotion.none),
              onPress: onOpen,
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
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      RouteLabels.date(context, route.startTime),
                      style: const TextStyle(
                        fontSize: 13,
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
            AppIconButton(
              tooltip: 'Route actions',
              icon: const Icon(FLucideIcons.ellipsisVertical),
              onPressed: () async {
                final action = await showAppActionSheet<String>(
                  context,
                  title: 'Route actions',
                  actions: [
                    if (onOpen != null)
                      SheetAction(
                        value: 'open',
                        icon: FLucideIcons.route,
                        label: route.status == Status.active
                            ? 'View route'
                            : 'View or rename',
                      ),
                    if (onDelete != null)
                      const SheetAction(
                        value: 'delete',
                        label: 'Delete',
                        icon: FLucideIcons.trash2,
                        destructive: true,
                      ),
                  ],
                );
                if (!context.mounted || action == null) return;
                action == 'delete' ? onDelete?.call() : onOpen?.call();
              },
            ),
        ],
      ),
      const SizedBox(height: 8),
      thumbnail,
      const SizedBox(height: 16),
      RouteStats(metrics: route.metrics),
    ],
  );
}
