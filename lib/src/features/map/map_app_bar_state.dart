part of 'map_app_bar_notifier.dart';

sealed class MapAppBarState extends Equatable {
  const MapAppBarState();
}

class MapAppBarUpdated extends MapAppBarState {
  @override
  List<Object?> get props => [];
}

class MapAppBarHasException extends MapAppBarState {
  const MapAppBarHasException({
    required this.showExceptionIconButton,
    required this.showExceptionDialog,
  });

  final bool showExceptionIconButton;
  final bool showExceptionDialog;

  MapAppBarHasException copyWith({
    bool? showExceptionIconButton,
    bool? showExceptionDialog,
  }) {
    return MapAppBarHasException(
      showExceptionIconButton:
          showExceptionIconButton ?? this.showExceptionIconButton,
      showExceptionDialog: showExceptionDialog ?? this.showExceptionDialog,
    );
  }

  @override
  List<Object?> get props => [
        showExceptionIconButton,
        showExceptionDialog,
      ];
}
