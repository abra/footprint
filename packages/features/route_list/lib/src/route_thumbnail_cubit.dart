import 'dart:typed_data';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:route_snapshots/route_snapshots.dart';

class RouteThumbnailState {
  const RouteThumbnailState({
    required this.scene,
    this.image,
    this.failed = false,
  });
  final RouteSnapshotScene scene;
  final Uint8List? image;
  final bool failed;
}

class RouteThumbnailCubit extends Cubit<RouteThumbnailState> {
  RouteThumbnailCubit({required RouteDM route, required this._snapshots})
    : super(RouteThumbnailState(scene: RouteSnapshotScene(route)));
  final RouteSnapshotRepository _snapshots;
  SnapshotRequest? _request;
  int _generation = 0;

  Future<void> load() async {
    if (isClosed || state.scene.points.isEmpty) return;
    final generation = ++_generation;
    _request?.cancel();
    emit(RouteThumbnailState(scene: state.scene));
    try {
      final request = _request = _snapshots.request(state.scene);
      final image = await request.image;
      if (!isClosed && generation == _generation) {
        emit(RouteThumbnailState(scene: state.scene, image: image));
      }
    } on Object catch (error, stack) {
      if (isClosed || generation != _generation) return;
      if (error is! SnapshotCancelled) addError(error, stack);
      emit(RouteThumbnailState(scene: state.scene, failed: true));
    }
  }

  @override
  Future<void> close() {
    _request?.cancel();
    return super.close();
  }
}
