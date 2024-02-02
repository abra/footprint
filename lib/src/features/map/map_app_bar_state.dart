part of 'map_app_bar_notifier.dart';

sealed class MapAppBarState extends Equatable {
  const MapAppBarState();
}

class MapAppBarUpdated extends MapAppBarState {
  const MapAppBarUpdated({
    required this.hasException,
    required this.showExceptionIconButton,
    required this.showExceptionDialog,
  });

  final bool hasException;
  final bool showExceptionIconButton;
  final bool showExceptionDialog;

  MapAppBarUpdated copyWith({
    bool? hasException,
    bool? showExceptionIconButton,
    bool? showExceptionDialog,
  }) {
    return MapAppBarUpdated(
      hasException: hasException ?? this.hasException,
      showExceptionIconButton:
          showExceptionIconButton ?? this.showExceptionIconButton,
      showExceptionDialog: showExceptionDialog ?? this.showExceptionDialog,
    );
  }

  @override
  List<Object?> get props => [
        hasException,
        showExceptionIconButton,
        showExceptionDialog,
      ];
}
