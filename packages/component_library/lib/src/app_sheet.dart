import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => showFSheet<T>(
  context: context,
  side: FLayout.btt,
  mainAxisMaxRatio: 0.85,
  useSafeArea: true,
  style: const .delta(barrierFilter: null),
  builder: (context) => AppSheet(child: builder(context)),
);

class AppSheet extends StatelessWidget {
  const AppSheet({super.key, required this.child});
  final Widget child;

  static const _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  );

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const ShapeDecoration(
      shape: _shape,
      shadows: [
        BoxShadow(
          color: Color(0x1A000000),
          blurRadius: 24,
          offset: Offset(0, -4),
        ),
      ],
    ),
    child: Material(
      color: context.theme.colors.background,
      shape: _shape,
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: context.theme.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Flexible(child: child),
          ],
        ),
      ),
    ),
  );
}
