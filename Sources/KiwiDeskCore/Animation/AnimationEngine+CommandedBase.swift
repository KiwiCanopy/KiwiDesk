import CoreGraphics

/// Commanded frame resolution for accumulating resize operations
/// (#1090, #129, #1056, #881, `TilingEngine.recentInstantTarget`).
extension AnimationEngine {
    /// Commanded frame for window: an in-flight animation target
    /// first, then the glide base — two records in separate
    /// domains, never merged. Only a glide STEP may read the base
    /// (`resizeFloating`, `HoldGlide.isApplyingGlideStep`, #1090).
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

    /// Records commanded floating window frame for subsequent
    /// glide steps. Every float resize records; only a glide step
    /// reads — record-all/read-glide-only is what keeps the base
    /// from becoming a #881-style stale stamp (#1090).
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
