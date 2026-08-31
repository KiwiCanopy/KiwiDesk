import CoreGraphics

/// Commanded frame resolution for accumulating resize operations
/// (#1090, #129, #1056, #881, `TilingEngine.recentInstantTarget`).
extension AnimationEngine {
    /// Commanded frame for window, prioritizing active in-flight animations
    /// (`resizeFloating`, `HoldGlide.isApplyingGlideStep`).
    public func commandedFrame(
        window: WindowID,
        includingHeldGlide: Bool
    ) -> CGRect? {
        if let target = targetFrame(window: window) {
            return target
        }
        guard includingHeldGlide else { return nil }
        return glideBase.frame(for: window)
    }

    /// Records commanded floating window frame for subsequent glide steps.
    func recordGlideCommanded(
        _ window: WindowID,
        frame: CGRect
    ) {
        glideBase.record(window, frame: frame)
    }

    /// Clears recorded glide frames on new physical press
    /// (`HoldGlide.onFireBegan`, `KiwiCore+HoldGlide.wireFireBegan`).
    func clearGlideCommanded() {
        glideBase.clear()
    }
}
