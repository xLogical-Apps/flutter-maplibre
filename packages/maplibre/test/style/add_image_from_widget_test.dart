import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre/maplibre.dart';

/// Records `addImage` and can be disposed while a widget is being rendered.
class _RecordingStyleController extends StyleController {
  final addedImageIds = <String>[];
  bool _disposed = false;

  @override
  bool get isDisposed => _disposed;

  @override
  void dispose() => _disposed = true;

  @override
  Future<void> addImage(String id, Uint8List bytes) async =>
      addedImageIds.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const widget = SizedBox.square(
    dimension: 8,
    child: ColoredBox(color: Color(0xFF000000)),
  );

  testWidgets('addImageFromWidget adds the rendered image', (tester) async {
    final style = _RecordingStyleController();
    await tester.runAsync(
      () => style.addImageFromWidget(
        id: 'marker',
        widget: widget,
        logicalSize: const Size.square(8),
        imageSize: const Size.square(8),
      ),
    );
    expect(style.addedImageIds, ['marker']);
  });

  testWidgets('addImageFromWidget drops the image when the controller was '
      'disposed while the widget was rendered', (tester) async {
    final style = _RecordingStyleController();
    await tester.runAsync(() async {
      final pending = style.addImageFromWidget(
        id: 'marker',
        widget: widget,
        logicalSize: const Size.square(8),
        imageSize: const Size.square(8),
      );
      // The map is replaced before the image bytes are ready.
      style.dispose();
      await pending;
    });
    expect(style.addedImageIds, isEmpty);
  });
}
