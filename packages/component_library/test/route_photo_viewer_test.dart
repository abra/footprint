import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    // Missing-file image streams must not leak between fake-async test zones.
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
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

  testWidgets(
    'viewer shows edited comments on the correct page and cancellation preserves them',
    (tester) async {
      String? nextComment = 'Beside the river';
      final editedIds = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          builder: AppTheme.builder,
          home: Builder(
            builder: (context) => Scaffold(
              body: AppButton(
                label: 'Open',
                onPressed: () => showRoutePhotoViewer(
                  context,
                  photos: photos,
                  selected: photos.first,
                  onEditComment: (_, photo) async {
                    editedIds.add(photo.id);
                    return nextComment;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add comment'));
      await tester.pumpAndSettle();
      expect(find.text('Beside the river'), findsOneWidget);
      expect(photos.first.comment, '');
      nextComment = null;
      await tester.tap(find.byTooltip('Edit comment'));
      await tester.pumpAndSettle();
      expect(find.text('Beside the river'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-700, 0));
      await tester.pumpAndSettle();
      expect(find.text('Beside the river'), findsNothing);
      nextComment = 'At the finish';
      await tester.tap(find.byTooltip('Add comment'));
      await tester.pumpAndSettle();
      expect(find.text('At the finish'), findsOneWidget);
      expect(editedIds, ['1', '1', '2']);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      nextComment = '';
      await tester.tap(find.byTooltip('Edit comment'));
      await tester.pumpAndSettle();
      expect(find.text('At the finish'), findsNothing);
      expect(find.byTooltip('Add comment'), findsOneWidget);
      await tester.tap(find.byTooltip('Close photo'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('viewer pages through photos and handles unavailable files', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: AppTheme.builder,
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
        builder: AppTheme.builder,
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
