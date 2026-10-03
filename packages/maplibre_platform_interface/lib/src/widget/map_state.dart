import 'package:flutter/widgets.dart';
import 'package:maplibre_platform_interface/maplibre_platform_interface.dart';
import 'package:maplibre_platform_interface/src/widget/inherited_model.dart';

/// The [State] of the [MapLibreMap] widget.
abstract class MapLibreMapState extends State<MapLibreMap>
    implements MapController {
  /// The counter is used to ensure an unique [viewName] for the platform view.
  static int _counter = 0;

  /// A unique name for the platform view.
  final viewName = 'plugins.flutter.io/maplibre${_counter++}';

  /// The [LayerManager] handles the high level markers, polygons,
  /// circles and polylines.
  LayerManager? layerManager;

  /// Get the [MapOptions] from [MapLibreMap.options].
  @override
  MapOptions get options => widget.options;

  /// The current camera, published to [MapLibreMap.children] through
  /// [MapCameraNotifier]. Assigning it notifies only the widgets that read
  /// the camera; it does not rebuild the map widget, and without readers it
  /// schedules no frame.
  final cameraPublisher = MapCameraPublisher();

  @override
  MapCamera? get camera => cameraPublisher.camera;

  set camera(MapCamera? value) => cameraPublisher.publish(value);

  /// Set to true once the map is initialized and a [MapController.camera]
  /// is set.
  bool isInitialized = false;

  @override
  void dispose() {
    cameraPublisher.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        buildPlatformWidget(context),
        MapLibreInheritedModel(
          mapController: this,
          child: MapCameraNotifier(
            publisher: cameraPublisher,
            child: isInitialized
                ? Stack(children: widget.children)
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  /// Build the platform specific widget.
  Widget buildPlatformWidget(BuildContext context);
}
