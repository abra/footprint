import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

part 'map_app_bar_state.dart';

class MapAppBarNotifier extends ValueNotifier<MapAppBarState> {
  MapAppBarNotifier()
      : super(
          const MapAppBarUpdated(
            hasException: false,
            showExceptionIconButton: false,
            showExceptionDialog: false,
          ),
        );

  void showException() async {
    value = const MapAppBarUpdated(
      hasException: true,
      showExceptionIconButton: false,
      showExceptionDialog: true,
    );
  }

  void hideException() async {
    value = const MapAppBarUpdated(
      hasException: false,
      showExceptionIconButton: false,
      showExceptionDialog: false,
    );
  }

  void showExceptionDialog() async {
    final appBarState = value;
    if (appBarState is MapAppBarUpdated) {
      final newState = appBarState.copyWith(
        showExceptionIconButton: false,
        showExceptionDialog: true,
      );
      value = newState;
    }
  }

  void showExceptionIcon() async {
    final appBarState = value;
    if (appBarState is MapAppBarUpdated) {
      final newState = appBarState.copyWith(
        showExceptionIconButton: true,
        showExceptionDialog: false,
      );
      value = newState;
    }
  }
}
