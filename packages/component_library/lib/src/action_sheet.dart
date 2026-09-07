import 'package:flutter/material.dart';

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
}) => showModalBottomSheet<T>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  showDragHandle: true,
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
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Text(message),
                ),
              const SizedBox(height: 8),
              for (final action in actions)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: Icon(action.icon),
                  title: Text(action.label),
                  selected: action.selected,
                  trailing: action.selected ? const Icon(Icons.check) : null,
                  textColor: action.destructive
                      ? Theme.of(context).colorScheme.error
                      : null,
                  iconColor: action.destructive
                      ? Theme.of(context).colorScheme.error
                      : null,
                  onTap: () => Navigator.pop(context, action.value),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(cancelLabel),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
