import AppKit

#if DEBUG
    /// A plate that draws nothing and owns no window, recording
    /// what it was asked, so a test core's sync costs no
    /// WindowServer transaction (#1894).
    @MainActor
    final class InertVisionPlate: VisionPlateBackend {
        private(set) var isShown = false
        /// Test-only: the window each order stacked under.
        private(set) var orders: [CGWindowID] = []
        /// Test-only: the last frame and dim handed in.
        private(set) var frame: CGRect?
        private(set) var dim: CGFloat?

        func update(frame: CGRect, dim: CGFloat) {
            self.frame = frame
            self.dim = dim
        }
        func order(below window: CGWindowID) { orders.append(window) }
        func show(reduceMotion: Bool) { isShown = true }
        func hide(reduceMotion: Bool) { isShown = false }
    }
#endif
