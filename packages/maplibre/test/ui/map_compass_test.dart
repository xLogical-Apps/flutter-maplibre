import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre/maplibre.dart';
import 'package:maplibre_platform_interface/src/widget/inherited_model.dart';
import 'package:mocktail/mocktail.dart';

import '../shared/mocks.dart';
import '../shared/ui_app.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(MockDuration());
  });

  group('MapCompass', () {
    testWidgets('check rotation', (tester) async {
      const camera = MapCamera(
        center: Geographic(lon: 0, lat: 0),
        zoom: 0,
        bearing: 12,
        pitch: 0,
      );
      final controller = MockMapController();
      when(controller.getCamera).thenReturn(camera);
      final app = App(
        camera: camera,
        controller: controller,
        children: const [MapCompass()],
      );
      await tester.pumpWidget(app);
      final transform = tester.firstWidget(find.byType(Transform)) as Transform;
      expect(transform.transform.storage[0], isNot(isZero));
      expect(transform.transform.storage[1], isNot(isZero));
    });

    testWidgets('rotates when the camera changes', (tester) async {
      MapCamera cameraWith({required double bearing}) => MapCamera(
        center: const Geographic(lon: 0, lat: 0),
        zoom: 0,
        bearing: bearing,
        pitch: 0,
      );
      final publisher = MapCameraPublisher()..publish(cameraWith(bearing: 10));
      addTearDown(publisher.dispose);
      final controller = MockMapController();
      when(controller.getCamera).thenReturn(cameraWith(bearing: 10));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapLibreInheritedModel(
              mapController: controller,
              child: MapCameraNotifier(
                publisher: publisher,
                child: const Stack(children: [MapCompass()]),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final compassTransform = find.descendant(
        of: find.byType(MapCompass),
        matching: find.byType(Transform),
      );
      double sine() =>
          tester.firstWidget<Transform>(compassTransform).transform.storage[1];
      final before = sine();

      publisher.publish(cameraWith(bearing: 90));
      await tester.pump();

      expect(sine(), isNot(closeTo(before, 0.01)));
    });

    testWidgets('reset rotation', (tester) async {
      const camera = MapCamera(
        center: Geographic(lon: 0, lat: 0),
        zoom: 0,
        bearing: 100,
        pitch: 0,
      );
      final controller = MockMapController();
      when(controller.getCamera).thenReturn(camera);
      when(
        () => controller.animateCamera(
          bearing: 0,
          webSpeed: any(named: 'webSpeed'),
          webMaxDuration: any(named: 'webMaxDuration'),
          nativeDuration: any(named: 'nativeDuration'),
          pitch: any(named: 'pitch'),
          zoom: any(named: 'zoom'),
          center: any(named: 'center'),
        ),
      ).thenAnswer((_) async {});
      final app = App(
        camera: camera,
        controller: controller,
        children: const [
          MapCompass(alignment: Alignment.topLeft, padding: EdgeInsets.zero),
        ],
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(InkWell));
      verify(
        () => controller.animateCamera(
          bearing: 0,
          center: any(named: 'center'),
          zoom: any(named: 'zoom'),
          pitch: any(named: 'pitch'),
          nativeDuration: any(named: 'nativeDuration'),
          webMaxDuration: any(named: 'webMaxDuration'),
          webSpeed: any(named: 'webSpeed'),
        ),
      ).called(1);
    });
  });
}
