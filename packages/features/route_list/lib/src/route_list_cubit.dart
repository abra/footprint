import 'package:domain_models/domain_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routes_repository/routes_repository.dart';

sealed class RouteListState {
  const RouteListState();
}

class RouteListLoading extends RouteListState {
  const RouteListLoading();
}

class RouteListLoaded extends RouteListState {
  RouteListLoaded(List<RouteDM> routes) : routes = List.unmodifiable(routes);
  final List<RouteDM> routes;
}

class RouteListFailure extends RouteListState {
  const RouteListFailure();
}

class RouteListCubit extends Cubit<RouteListState> {
  RouteListCubit({required RoutesRepository routesRepository})
    : _repository = routesRepository,
      super(const RouteListLoading());

  final RoutesRepository _repository;
  int _request = 0;

  Future<void> load() async {
    final request = ++_request;
    emit(const RouteListLoading());
    try {
      final routes = await _repository.getRoutes();
      if (!isClosed && request == _request) emit(RouteListLoaded(routes));
    } on Object catch (error, stack) {
      if (isClosed || request != _request) return;
      addError(error, stack);
      emit(const RouteListFailure());
    }
  }
}
