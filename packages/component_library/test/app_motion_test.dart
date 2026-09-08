import 'package:component_library/component_library.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  double opacity(WidgetTester tester, int value) => tester
      .widget<FadeTransition>(
        find.ancestor(
          of: find.byKey(ValueKey('view-$value')),
          matching: find.byType(FadeTransition),
        ),
      )
      .opacity
      .value;

  testWidgets('fade uses current bounds and excludes outgoing interaction', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(const _Host());
      final host = tester.state<_HostState>(find.byType(_Host));
      expect(opacity(tester, 0), 1);
      expect(tester.hasRunningAnimations, isFalse);
      host.show(1);
      await tester.pump();
      final builds = host.builds;
      expect(tester.getSize(find.byType(AppFadeSwitcher)).height, 100);
      await tester.pump(const Duration(milliseconds: 60));
      expect(opacity(tester, 0), inExclusiveRange(0, 1));
      expect(opacity(tester, 1), 0);
      await tester.pump(const Duration(milliseconds: 60));
      expect(opacity(tester, 0), 0);
      expect(opacity(tester, 1), inExclusiveRange(0, 1));
      expect(
        host.builds,
        builds,
        reason: 'Fade frames must not rebuild content.',
      );
      expect(tester.getSize(find.byType(AppFadeSwitcher)).height, 100);
      expect(find.bySemanticsLabel('View 0'), findsNothing);
      expect(find.bySemanticsLabel('View 1'), findsOneWidget);
      expect(find.text('View 0').hitTestable(), findsNothing);
      expect(
        Focus.of(tester.element(find.text('View 0'))).canRequestFocus,
        isFalse,
      );
      await tester.tap(find.text('View 1'));
      expect(host.taps, [1]);
      await tester.pumpAndSettle();
      expect(find.text('View 0'), findsNothing);
      expect(opacity(tester, 1), 1);
      expect(tester.hasRunningAnimations, isFalse);
      final settledBuilds = host.builds;
      await tester.pump(const Duration(seconds: 1));
      expect(host.builds, settledBuilds);
      expect(tester.binding.hasScheduledFrame, isFalse);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('same-view updates do not animate and quick changes settle', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host());
    final host = tester.state<_HostState>(find.byType(_Host));
    host.show(0);
    await tester.pump();
    expect(opacity(tester, 0), 1);
    expect(tester.hasRunningAnimations, isFalse);
    for (final value in [1, 0, 1, 0]) {
      host.show(value);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pumpAndSettle();
    expect(find.text('View 0'), findsOneWidget);
    expect(find.text('View 1'), findsNothing);
    expect(opacity(tester, 0), 1);
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion switches immediately', (tester) async {
    await tester.pumpWidget(const _Host(reducedMotion: true));
    final host = tester.state<_HostState>(find.byType(_Host));
    host.show(1);
    await tester.pump();
    expect(find.text('View 0'), findsNothing);
    expect(opacity(tester, 1), 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('enabling reduced motion ends an in-flight fade', (tester) async {
    await tester.pumpWidget(const _Host());
    final host = tester.state<_HostState>(find.byType(_Host));
    host.show(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(opacity(tester, 1), inExclusiveRange(0, 1));
    host.reduceMotion();
    await tester.pump();
    expect(find.text('View 0'), findsNothing);
    expect(opacity(tester, 1), 1);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('unmounting during a fade releases animation tickers', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host());
    tester.state<_HostState>(find.byType(_Host)).show(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);
  });
}

class _Host extends StatefulWidget {
  const _Host({this.reducedMotion = false});
  final bool reducedMotion;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late bool reducedMotion = widget.reducedMotion;
  int value = 0;
  int builds = 0;
  final taps = <int>[];

  void show(int next) => setState(() => value = next);
  void reduceMotion() => setState(() => reducedMotion = true);

  @override
  Widget build(BuildContext context) {
    final selected = value;
    return MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 240,
            child: AppFadeSwitcher(
              value: selected,
              child: Builder(
                builder: (context) {
                  builds++;
                  return Focus(
                    child: Semantics(
                      label: 'View $selected',
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => taps.add(selected),
                        child: SizedBox(
                          key: ValueKey('view-$selected'),
                          height: selected == 0 ? 200 : 100,
                          child: Center(child: Text('View $selected')),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
