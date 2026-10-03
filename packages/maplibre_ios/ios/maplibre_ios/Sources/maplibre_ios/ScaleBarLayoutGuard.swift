import MapLibre
import ObjectiveC
import UIKit

/// Keeps the hidden native scale bar from forcing Flutter frames.
///
/// `MLNMapView.layoutSubviews` invalidates the intrinsic content size of its
/// scale bar on every layout pass, even while the scale bar is hidden
/// (MapLibre iOS 6.x, `MLNMapView.mm`). The invalidation travels up the Auto
/// Layout container chain to the `FlutterView`; its view controller then
/// re-sends the viewport metrics and Flutter renders a forced frame.
///
/// Every heading change triggers such a layout pass, because the (hidden)
/// compass view is rotated and that marks the map view's layer for layout.
/// Following a moving position with a rotating map therefore produced one
/// full Flutter frame per camera step, several hundred per minute, although
/// nothing in the Flutter tree changed.
///
/// The guard gives the scale bar's class its own
/// `invalidateIntrinsicContentSize` that does nothing while the scale bar is
/// hidden and calls through otherwise, so a visible scale bar behaves as
/// before.
enum ScaleBarLayoutGuard {
    private static var installed = false

    private typealias Invalidate = @convention(c) (AnyObject, Selector) -> Void

    static func install(on mapView: MLNMapView) {
        guard !installed else { return }
        let scaleBar: UIView = mapView.scaleBar
        // Only patch the dedicated scale bar class, never UIView itself.
        guard let scaleBarClass = object_getClass(scaleBar), scaleBarClass != UIView.self else {
            return
        }
        let selector = #selector(UIView.invalidateIntrinsicContentSize)
        guard let inherited = class_getInstanceMethod(scaleBarClass, selector) else { return }
        let original = unsafeBitCast(method_getImplementation(inherited), to: Invalidate.self)
        let guarded: @convention(block) (UIView) -> Void = { view in
            if view.isHidden { return }
            original(view, selector)
        }
        let implementation = imp_implementationWithBlock(guarded)
        // Adds an override when the class inherits the method; replaces the
        // class's own implementation otherwise.
        if !class_addMethod(
            scaleBarClass, selector, implementation, method_getTypeEncoding(inherited)
        ) {
            method_setImplementation(inherited, implementation)
        }
        installed = true
    }
}
