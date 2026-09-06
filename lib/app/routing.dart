import 'package:flutter/material.dart';
import 'package:footprint/app/dependency_container.dart';
import 'package:go_router/go_router.dart';
import 'package:map/map.dart';
import 'package:route_list/route_list.dart';
import 'package:route_details/route_details.dart';

abstract final class AppRoutes {
  static const map = '/map';
  static const routes = '/routes';
}

GoRouter buildRouter({required DependenciesContainer dependencies}) {
  return GoRouter(
    initialLocation: AppRoutes.map,
    routes: [
      GoRoute(
        path: AppRoutes.map,
        pageBuilder: (context, state) => _materialPage<void>(
          state,
          MapScreen(
            photosRepository: dependencies.photosRepository,
            recordingService: dependencies.recordingService,
            geocodingManager: dependencies.geocodingManager,
            config: dependencies.config.map,
            onPageChangeRequested: () => context.push(AppRoutes.routes),
            onRouteCompleted: (id) =>
                context.push('${AppRoutes.routes}/$id?recorded=true'),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.routes,
        pageBuilder: (context, state) => _materialPage<void>(
          state,
          RouteListScreen(
            routesRepository: dependencies.routesRepository,
            config: dependencies.config.map,
            onRouteRequested: (id) async {
              await context.push('${AppRoutes.routes}/$id');
            },
            onPageChangeRequested: () =>
                context.canPop() ? context.pop() : context.go(AppRoutes.map),
          ),
        ),
      ),
      GoRoute(
        path: '${AppRoutes.routes}/:id',
        pageBuilder: (context, state) => _materialPage<bool>(
          state,
          RouteDetailsScreen(
            photosRepository: dependencies.photosRepository,
            routeId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
            repository: dependencies.routesRepository,
            config: dependencies.config.map,
            justRecorded: state.uri.queryParameters['recorded'] == 'true',
            onClosed: (changed) => context.canPop()
                ? context.pop(changed)
                : context.go(AppRoutes.routes),
          ),
        ),
      ),
    ],
  );
}

// go_router 18 detects material_ui.MaterialApp, not Flutter's MaterialApp.
MaterialPage<T> _materialPage<T>(GoRouterState state, Widget child) =>
    MaterialPage<T>(
      key: state.pageKey,
      name: state.name ?? state.path,
      arguments: {...state.pathParameters, ...state.uri.queryParameters},
      restorationId: state.pageKey.value,
      child: child,
    );
