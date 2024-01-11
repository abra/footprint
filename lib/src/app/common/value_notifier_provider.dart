import 'package:flutter/material.dart';

class ValueNotifierProvider<T> extends InheritedWidget {
  final ValueNotifier<T> valueNotifier;

  const ValueNotifierProvider({
    super.key,
    required this.valueNotifier,
    required super.child,
  });

  static ValueNotifierProvider<T> of<T>(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ValueNotifierProvider<T>>()!;
  }

  @override
  bool updateShouldNotify(ValueNotifierProvider<T> oldWidget) {
    return oldWidget.valueNotifier != valueNotifier;
  }
}
