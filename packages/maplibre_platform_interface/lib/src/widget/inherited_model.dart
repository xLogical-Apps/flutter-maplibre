import 'package:flutter/widgets.dart';
import 'package:maplibre_platform_interface/maplibre_platform_interface.dart';

/// The [InheritedModel] makes it possible to call `MapController.of(context)`.
///
/// https://api.flutter.dev/flutter/widgets/InheritedModel-class.html
///
/// The camera is not part of this model: it changes with every camera event
/// and is published through [MapCameraNotifier] instead, so only widgets
/// that read it rebuild.
class MapLibreInheritedModel extends InheritedModel<MapController> {
  /// Default constructor
  const MapLibreInheritedModel({
    required super.child,
    required this.mapController,
    super.key,
  });

  /// [MapController] instance.
  final MapController mapController;

  /// Get the [InheritedModel] that is used to inject models into the widget
  /// tree that can referenced further down in the widget tree.
  static MapLibreInheritedModel? maybeOf(BuildContext context) =>
      InheritedModel.inheritFrom<MapLibreInheritedModel>(context);

  /// Get the in the widget tree injected [MapController].
  /// Used in [MapController.maybeOf].
  static MapController? maybeMapControllerOf(BuildContext context) =>
      maybeOf(context)?.mapController;

  /// Get the in the widget tree injected [MapCamera].
  /// Used in [MapCamera.maybeOf].
  static MapCamera? maybeMapCameraOf(BuildContext context) =>
      MapCameraNotifier.maybeOf(context);

  @override
  bool updateShouldNotify(covariant MapLibreInheritedModel oldWidget) {
    return oldWidget.mapController != mapController;
  }

  @override
  bool updateShouldNotifyDependent(
    covariant MapLibreInheritedModel oldWidget,
    Set<MapController> dependencies,
  ) {
    return oldWidget.mapController != mapController;
  }
}

/// Holds the current [MapCamera] of a map and publishes changes only to
/// widgets that read it.
///
/// The camera changes with every camera event — while following a moving
/// position that is several hundred times a minute. Rebuilding the map
/// state for each change produced a Flutter frame per event even when no
/// child read the camera. The publisher keeps the camera in a plain field
/// and only forwards it to the [notifier] once a widget has read the
/// camera from the tree ([markRead]); until then a camera change marks
/// nothing dirty and schedules no frame.
class MapCameraPublisher {
  /// Listened to by [MapCameraNotifier]; only updated once the camera has
  /// been read from the widget tree.
  final notifier = ValueNotifier<MapCamera?>(null);

  MapCamera? _camera;
  bool _read = false;

  /// The current camera.
  MapCamera? get camera => _camera;

  /// Whether a widget has read the camera from the tree.
  bool get hasReaders => _read;

  /// Stores [camera] and notifies readers, if there are any.
  void publish(MapCamera? camera) {
    _camera = camera;
    if (_read) notifier.value = camera;
  }

  /// Called from [MapCamera.maybeOf]: from now on every camera change
  /// notifies the readers.
  void markRead() {
    if (_read) return;
    _read = true;
    // The first read happens during a build; the notifier catches up right
    // after the frame so the reader is not marked dirty mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifier.value = _camera;
    });
  }

  /// Releases the notifier.
  void dispose() => notifier.dispose();
}

/// Publishes the current [MapCamera] to the [MapLibreMap.children] through
/// a [MapCameraPublisher].
///
/// Only widgets that read the camera ([MapCamera.maybeOf]) rebuild on a
/// camera change; the rest of the map widget, and therefore the Flutter
/// frame pipeline, stays idle. Without any reader a camera change schedules
/// no frame at all.
class MapCameraNotifier extends InheritedNotifier<ValueNotifier<MapCamera?>> {
  /// Default constructor
  MapCameraNotifier({required this.publisher, required super.child, super.key})
    : super(notifier: publisher.notifier);

  /// The publisher that owns the camera.
  final MapCameraPublisher publisher;

  /// Get the current [MapCamera] from the closest [MapCameraNotifier] and
  /// rebuild the calling widget whenever it changes.
  static MapCamera? maybeOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<MapCameraNotifier>();
    if (scope == null) return null;
    scope.publisher.markRead();
    return scope.publisher.camera;
  }
}
