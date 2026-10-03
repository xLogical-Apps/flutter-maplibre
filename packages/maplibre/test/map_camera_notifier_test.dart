import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre/maplibre.dart';
import 'package:maplibre_platform_interface/src/widget/inherited_model.dart';

import 'shared/mocks.dart';

/// Counts its own builds and optionally reads the camera.
class _Probe extends StatelessWidget {
  const _Probe({required this.readsCamera, required this.builds});

  final bool readsCamera;
  final List<int> builds;

  @override
  Widget build(BuildContext context) {
    builds.add(builds.length);
    final camera = readsCamera ? MapCamera.maybeOf(context) : null;
    return Text('${camera?.zoom}', textDirection: TextDirection.ltr);
  }
}

void main() {
  const first = MapCamera(
    center: Geographic(lon: 0, lat: 0),
    zoom: 1,
    bearing: 0,
    pitch: 0,
  );
  const second = MapCamera(
    center: Geographic(lon: 0, lat: 0),
    zoom: 2,
    bearing: 0,
    pitch: 0,
  );

  Widget tree(MapCameraPublisher publisher, List<Widget> children) =>
      MapLibreInheritedModel(
        mapController: MockMapController(),
        child: MapCameraNotifier(
          publisher: publisher,
          child: Column(children: children),
        ),
      );

  group('MapCameraNotifier', () {
    testWidgets('a camera change rebuilds only widgets reading the camera', (
      tester,
    ) async {
      final publisher = MapCameraPublisher()..publish(first);
      addTearDown(publisher.dispose);
      final reader = <int>[];
      final bystander = <int>[];
      await tester.pumpWidget(
        tree(publisher, [
          _Probe(readsCamera: true, builds: reader),
          _Probe(readsCamera: false, builds: bystander),
        ]),
      );
      // The first read syncs the notifier after the frame, which may
      // rebuild the reader once more; measure from the settled state.
      await tester.pump();
      final readerBuilds = reader.length;
      final bystanderBuilds = bystander.length;
      expect(find.text('1.0'), findsOneWidget);

      publisher.publish(second);
      await tester.pump();

      expect(reader, hasLength(readerBuilds + 1));
      expect(bystander, hasLength(bystanderBuilds));
      expect(find.text('2.0'), findsOneWidget);
    });

    testWidgets('without readers a camera change schedules no frame', (
      tester,
    ) async {
      final publisher = MapCameraPublisher()..publish(first);
      addTearDown(publisher.dispose);
      final bystander = <int>[];
      await tester.pumpWidget(
        tree(publisher, [_Probe(readsCamera: false, builds: bystander)]),
      );
      expect(tester.binding.hasScheduledFrame, isFalse);

      publisher.publish(second);

      expect(publisher.hasReaders, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(publisher.camera, second);
    });

    testWidgets('a reader sees the current camera on its first build', (
      tester,
    ) async {
      final publisher = MapCameraPublisher()..publish(first);
      addTearDown(publisher.dispose);
      publisher.publish(second);
      final builds = <int>[];
      await tester.pumpWidget(
        tree(publisher, [_Probe(readsCamera: true, builds: builds)]),
      );
      expect(find.text('2.0'), findsOneWidget);
      expect(publisher.hasReaders, isTrue);
    });

    testWidgets('MapCamera.of throws outside of a map', (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      );
      expect(MapCamera.maybeOf(captured), isNull);
      expect(() => MapCamera.of(captured), throwsStateError);
    });
  });
}
