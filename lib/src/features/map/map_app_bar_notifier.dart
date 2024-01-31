import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

part 'map_app_bar_state.dart';

class MapAppBarNotifier extends ValueNotifier<MapAppBarState> {
  MapAppBarNotifier() : super(MapAppBarUpdated());

  void showException() async {
    value = const MapAppBarHasException(
      showExceptionIconButton: false,
      showExceptionDialog: true,
    );
  }

  void hideException() async {
    value = MapAppBarUpdated();
  }

  void showExceptionDialog() async {
    final appBarState = value;
    if (appBarState is MapAppBarHasException) {
      final newState = appBarState.copyWith(
        showExceptionIconButton: false,
        showExceptionDialog: true,
      );
      value = newState;
    }
  }

  void showExceptionIcon() async {
    final appBarState = value;
    if (appBarState is MapAppBarHasException) {
      final newState = appBarState.copyWith(
        showExceptionIconButton: true,
        showExceptionDialog: false,
      );
      value = newState;
    }
  }
}
