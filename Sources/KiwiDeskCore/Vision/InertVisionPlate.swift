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
        func order(below window: CGWindowID) { orders.append(window) }
        func show(reduceMotion: Bool) { isShown = true }
        func hide(reduceMotion: Bool) { isShown = false }
    }

    /// A float panel that draws nothing and owns no window,
    /// recording what it was asked (#1894).
    @MainActor
    final class InertFloatDim: FloatDimBackend {
        private(set) var isShown = false
        /// Test-only: the window each order stacked above.
        private(set) var orders: [CGWindowID] = []
        private(set) var frame: CGRect?
        private(set) var cornerRadius: CGFloat?
        private(set) var dim: CGFloat?
        private(set) var blur: Bool?
        private(set) var spans = false
        private(set) var orderedOut = 0

        func update(
            frame: CGRect,
            cornerRadius: CGFloat,
            dim: CGFloat,
            blur: Bool
        ) {
            self.frame = frame
            self.cornerRadius = cornerRadius
            self.dim = dim
            self.blur = blur
        }
        func order(above window: CGWindowID) { orders.append(window) }
        func show(reduceMotion: Bool) { isShown = true }
        func hide(reduceMotion: Bool) { isShown = false }
        func orderOut() { orderedOut += 1 }
        func retire(reduceMotion: Bool) {
            isShown = false
            orderedOut += 1
        }
        func setSpansDesktops(_ on: Bool) { spans = on }
    }
#endif
