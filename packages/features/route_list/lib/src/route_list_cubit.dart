import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routes_repository/routes_repository.dart';

sealed class RouteListState {
  const RouteListState();
}

class RouteListLoading extends RouteListState {
  const RouteListLoading();
}

class RouteListFailure extends RouteListState {
  const RouteListFailure();
}

class RouteListLoaded extends RouteListState {
  RouteListLoaded(
    List<RouteDM> routes, {
    this.hasMore = false,
    this.loadingMore = false,
    this.deletingId,
    this.error,
  }) : routes = List.unmodifiable(routes);
  final List<RouteDM> routes;
  final bool hasMore;
  final bool loadingMore;
  final int? deletingId;
  final String? error;
}

class RouteListCubit extends Cubit<RouteListState> {
  RouteListCubit({
    required RoutesRepository routesRepository,
    this.onRouteDeleted,
  }) : _repository = routesRepository,
       super(const RouteListLoading());
  static const pageSize = 20;
  final RoutesRepository _repository;
  final Future<void> Function(int)? onRouteDeleted;
  int _request = 0;
  String _query = '';
  RouteSort _sort = RouteSort.newest;
  Timer? _debounce;
  RouteSort get sort => _sort;
  String get query => _query;

  void search(String value) {
    if (isClosed || value.trim() == _query) return;
    _query = value.trim();
    _request++;
    emit(const RouteListLoading());
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), load);
  }

  void sortBy(RouteSort value) {
    if (isClosed || value == _sort) return;
    _sort = value;
    unawaited(load());
  }

  Future<void> load() async {
    if (isClosed) return;
    _debounce?.cancel();
    final request = ++_request;
    emit(const RouteListLoading());
    try {
      final routes = await _repository.getRoutePage(
        query: _query,
        sort: _sort,
        limit: pageSize,
      );
      if (!isClosed && request == _request) {
        emit(RouteListLoaded(routes, hasMore: routes.length == pageSize));
      }
    } on Object catch (error, stack) {
      if (isClosed || request != _request) return;
      addError(error, stack);
      emit(const RouteListFailure());
    }
  }

  Future<void> loadMore() async {
    if (isClosed) return;
    final current = state;
    if (current is! RouteListLoaded ||
        current.loadingMore ||
        !current.hasMore ||
        current.deletingId != null) {
      return;
    }
    final request = ++_request;
    emit(RouteListLoaded(current.routes, hasMore: true, loadingMore: true));
    try {
      final page = await _repository.getRoutePage(
        query: _query,
        sort: _sort,
        offset: current.routes.length,
        limit: pageSize,
      );
      if (isClosed || request != _request) return;
      final byId = {
        for (final route in [...current.routes, ...page]) route.id: route,
      };
      emit(
        RouteListLoaded(byId.values.toList(), hasMore: page.length == pageSize),
      );
    } on Object catch (error, stack) {
      if (isClosed || request != _request) return;
      addError(error, stack);
      emit(
        RouteListLoaded(
          current.routes,
          hasMore: true,
          error: 'More routes could not be loaded.',
        ),
      );
    }
  }

  Future<void> delete(RouteDM route) async {
    if (isClosed || route.status == Status.active) return;
    final current = state;
    if (current is! RouteListLoaded || current.deletingId != null) return;
    final request = ++_request;
    emit(
      RouteListLoaded(
        current.routes,
        hasMore: current.hasMore,
        deletingId: route.id,
      ),
    );
    try {
      await _repository.deleteRoute(route.id);
      await onRouteDeleted?.call(route.id);
      if (!isClosed && request == _request) await load();
    } on Object catch (error, stack) {
      if (isClosed || request != _request) return;
      addError(error, stack);
      emit(
        RouteListLoaded(
          current.routes,
          hasMore: current.hasMore,
          error: 'Route could not be deleted.',
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
