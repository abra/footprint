import 'package:flutter/widgets.dart';
import 'package:footprint/app/dependency_container.dart';
import 'package:go_router/go_router.dart';
import 'package:map/map.dart';
import 'package:route_list/route_list.dart';

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
        builder: (context, state) => MapScreen(
          locationService: dependencies.foregroundLocationService,
          routesRepository: dependencies.routesRepository,
          geocodingManager: dependencies.geocodingManager,
          onPageChangeRequested: () => context.go(AppRoutes.routes),
        ),
      ),
      GoRoute(
        path: AppRoutes.routes,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: RouteListScreen(
            routesRepository: dependencies.routesRepository,
            onPageChangeRequested: () => context.go(AppRoutes.map),
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
    ],
  );
}
