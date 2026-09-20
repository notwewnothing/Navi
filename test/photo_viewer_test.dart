import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navi/theme/palette.dart';
import 'package:navi/widgets/nd_photo_viewer.dart';

void main() {
  // absolute paths keep MediaStore off path_provider, which is not bound here
  const photo = '/tmp/a.jpg';

  Widget host() => MaterialApp(
    theme: NaviPalette(accents.first).toThemeData(),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => openPhotoViewer(context, photo: photo),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  test('hero tags are stable and unique per photo', () {
    expect(photoHeroTag('/tmp/a.jpg'), photoHeroTag('/tmp/a.jpg'));
    expect(photoHeroTag('/tmp/a.jpg'), isNot(photoHeroTag('/tmp/b.jpg')));
  });

  testWidgets('the photo is zoomable and starts unzoomed', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(viewer.maxScale, 6);
    // panning stays off until zoomed so it cannot fight the dismiss drag
    expect(viewer.panEnabled, isFalse);
  });

  testWidgets('double tap zooms in, and again zooms back out', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final target = find.byType(InteractiveViewer);
    double scale() => tester
        .widget<InteractiveViewer>(target)
        .transformationController!
        .value
        .getMaxScaleOnAxis();

    expect(scale(), closeTo(1.0, 0.01));

    await tester.tap(target);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(scale(), greaterThan(1.5));

    await tester.tap(target);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(scale(), closeTo(1.0, 0.01));
  });

  testWidgets('swiping down far enough dismisses the viewer', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(NdPhotoViewer), findsOneWidget);

    await tester.drag(find.byType(NdPhotoViewer), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.byType(NdPhotoViewer), findsNothing);
  });

  testWidgets('a short downward drag springs back instead', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(NdPhotoViewer), const Offset(0, 40));
    await tester.pumpAndSettle();
    expect(find.byType(NdPhotoViewer), findsOneWidget);
  });

}
