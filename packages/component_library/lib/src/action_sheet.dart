import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import 'app_button.dart';
import 'app_sheet.dart';
import 'app_tile_list.dart';

class SheetAction<T> {
  const SheetAction({
    required this.value,
    required this.label,
    required this.icon,
    this.destructive = false,
    this.selected = false,
  });
  final T value;
  final String label;
  final IconData icon;
  final bool destructive;
  final bool selected;
}

Future<T?> showAppActionSheet<T>(
  BuildContext context, {
  required String title,
  String? message,
  required List<SheetAction<T>> actions,
  String cancelLabel = 'Cancel',
}) => showAppSheet<T>(
  context: context,
  builder: (context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.8,
    ),
    child: SingleChildScrollView(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(message),
                ),
              const SizedBox(height: 16),
              AppTileList(
                children: [
                  for (final action in actions)
                    FTile(
                      style: const .delta(shape: null),
                      prefix: Icon(action.icon),
                      title: Text(action.label, overflow: TextOverflow.visible),
                      selected: action.selected,
                      suffix: action.selected
                          ? const Icon(FLucideIcons.check)
                          : null,
                      variant: action.destructive
                          ? FItemVariant.destructive
                          : FItemVariant.primary,
                      onPress: () => Navigator.pop(context, action.value),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              AppButton(
                variant: FButtonVariant.secondary,
                onPressed: () => Navigator.pop(context),
                label: cancelLabel,
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
