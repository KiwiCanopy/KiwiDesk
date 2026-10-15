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
        private(set) var blur: Bool?

        func update(frame: CGRect, dim: CGFloat, blur: Bool) {
            self.frame = frame
            self.dim = dim
            self.blur = blur
        }
        /// Test-only: every mask handed in, nil for the whole
        /// screen.
        private(set) var shapes: [CGPath?] = []

        func reshape(_ path: CGPath?) { shapes.append(path) }
        func order(below window: CGWindowID) { orders.append(window) }
        func show(reduceMotion: Bool) { isShown = true }
        func hide(reduceMotion: Bool) { isShown = false }
    }
#endif
