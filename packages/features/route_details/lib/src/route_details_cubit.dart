import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routes_repository/routes_repository.dart';

sealed class RouteDetailsState {
  const RouteDetailsState();
}

class RouteDetailsLoading extends RouteDetailsState {
  const RouteDetailsLoading();
}

class RouteDetailsFailure extends RouteDetailsState {
  const RouteDetailsFailure(this.message);
  final String message;
}

class RouteDetailsReady extends RouteDetailsState {
  const RouteDetailsReady({
    required this.route,
    required this.name,
    this.saving = false,
    this.saved = false,
    this.error,
    this.photos = const [],
    this.photoError,
    this.photoBusy = false,
  });
  final RouteDM route;
  final String name;
  final bool saving;
  final bool saved;
  final String? error;
  final List<RoutePhotoDM> photos;
  final String? photoError;
  final bool photoBusy;
  bool get dirty => name.trim() != (route.name ?? '');

  RouteDetailsReady copyWith({
    String? name,
    bool? saving,
    bool? saved,
    String? error,
    bool clearError = false,
    List<RoutePhotoDM>? photos,
    bool? photoBusy,
    String? photoError,
    bool clearPhotoError = false,
  }) => RouteDetailsReady(
    route: route,
    name: name ?? this.name,
    saving: saving ?? this.saving,
    saved: saved ?? this.saved,
    error: clearError ? null : error ?? this.error,
    photos: photos == null ? this.photos : List.unmodifiable(photos),
    photoBusy: photoBusy ?? this.photoBusy,
    photoError: clearPhotoError ? null : photoError ?? this.photoError,
  );
}

class RouteDetailsCubit extends Cubit<RouteDetailsState> {
  RouteDetailsCubit({
    required this._repository,
    required this._routeId,
    required RoutePhotosRepository photosRepository,
  }) : _photos = photosRepository,
       super(const RouteDetailsLoading()) {
    _subscription = _photos.changes.listen((id) {
      if (id == _routeId) unawaited(loadPhotos());
    });
  }

  final RoutesRepository _repository;
  final int _routeId;
  final RoutePhotosRepository _photos;
  StreamSubscription<int>? _subscription;
  int _photoRequest = 0;
  int _request = 0;

  Future<void> load() async {
    if (isClosed) return;
    if (state
        case RouteDetailsReady(saving: true) ||
            RouteDetailsReady(photoBusy: true)) {
      return;
    }
    final request = ++_request;
    emit(const RouteDetailsLoading());
    try {
      final route = await _repository.getRoute(_routeId);
      if (isClosed || request != _request) return;
      emit(
        route == null
            ? const RouteDetailsFailure('Route not found.')
            : RouteDetailsReady(route: route, name: route.name ?? ''),
      );
      if (route != null) await loadPhotos();
    } on Object catch (error, stack) {
      if (isClosed || request != _request) return;
      addError(error, stack);
      emit(const RouteDetailsFailure('Route could not be loaded.'));
    }
  }

  void changeName(String value) {
    if (isClosed) return;
    if (state case final RouteDetailsReady current when !current.saving) {
      emit(current.copyWith(name: value, saved: false, clearError: true));
    }
  }

  Future<void> save() async {
    if (isClosed) return;
    final current = state;
    if (current is! RouteDetailsReady ||
        current.saving ||
        current.photoBusy ||
        current.saved ||
        current.route.status != Status.completed) {
      return;
    }
    final name = current.name.trim();
    if (name.isEmpty || name.runes.length > 80) {
      emit(
        current.copyWith(error: 'Enter a name between 1 and 80 characters.'),
      );
      return;
    }
    emit(current.copyWith(name: name, saving: true, clearError: true));
    try {
      await _repository.renameRoute(_routeId, name);
      if (!isClosed) {
        emit(
          (state as RouteDetailsReady).copyWith(
            name: name,
            saving: false,
            saved: true,
          ),
        );
      }
    } on Object catch (error, stack) {
      if (isClosed) return;
      addError(error, stack);
      emit(
        (state as RouteDetailsReady).copyWith(
          name: name,
          saving: false,
          error: 'Name could not be saved. Your recorded route is still available.',
        ),
      );
    }
  }

  Future<void> loadPhotos() async {
    if (isClosed) return;
    final request = ++_photoRequest;
    try {
      final photos = await _photos.getPhotos(_routeId);
      if (isClosed || request != _photoRequest) return;
      if (state case final RouteDetailsReady current) {
        emit(current.copyWith(photos: photos, clearPhotoError: true));
      }
    } on Object catch (error, stack) {
      if (isClosed || request != _photoRequest) return;
      addError(error, stack);
      if (state case final RouteDetailsReady current) {
        emit(current.copyWith(photoError: 'Photos could not be loaded.'));
      }
    }
  }

  Future<bool> deletePhoto(String id) async {
    final current = state;
    if (isClosed ||
        current is! RouteDetailsReady ||
        current.photoBusy ||
        current.saving ||
        current.route.status != Status.completed) {
      return false;
    }
    emit(current.copyWith(photoBusy: true, clearPhotoError: true));
    try {
      await _photos.deletePhoto(_routeId, id);
      if (!isClosed) await loadPhotos();
      return true;
    } on Object catch (error, stack) {
      if (!isClosed) {
        addError(error, stack);
        if (state case final RouteDetailsReady ready) {
          emit(ready.copyWith(photoError: 'Photo could not be deleted.'));
        }
      }
      return false;
    } finally {
      if (!isClosed) {
        if (state case final RouteDetailsReady ready) {
          emit(ready.copyWith(photoBusy: false));
        }
      }
    }
  }

  @override
  Future<void> close() =>
      Future.wait<void>([super.close(), ?_subscription?.cancel()]).then((_) {});
}
