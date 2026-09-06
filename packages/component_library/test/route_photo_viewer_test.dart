import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final photos = [
    for (final id in [1, 2])
      RoutePhotoDM(
        id: '$id',
        routeId: 1,
        path: '/missing-$id.png',
        latitude: 56,
        longitude: 60,
        capturedAt: DateTime(2026),
      ),
  ];

  testWidgets('viewer pages through photos and handles unavailable files', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: IconButton(
              tooltip: 'Open',
              icon: const Icon(Icons.photo),
              onPressed: () => showRoutePhotoViewer(
                context,
                photos: photos,
                selected: photos.first,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Open'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsWidgets);
    expect(find.byTooltip('Photo file unavailable'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Close photo'));
    await tester.pumpAndSettle();
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('deletion requires confirmation and failure remains retryable', (
    tester,
  ) async {
    var calls = 0;
    var succeed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: IconButton(
              tooltip: 'Open',
              icon: const Icon(Icons.photo),
              onPressed: () => showRoutePhotoViewer(
                context,
                photos: photos,
                selected: photos.first,
                onDelete: (_) async {
                  calls++;
                  return succeed;
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.tap(find.byTooltip('Delete photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Photo could not be deleted.'), findsOneWidget);
    succeed = true;
    await tester.tap(find.byTooltip('Delete photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.byType(PageView), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
