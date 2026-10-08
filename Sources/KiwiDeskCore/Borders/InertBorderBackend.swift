import AppKit

#if DEBUG
    /// A ring backend that draws nothing and owns no window, so a
    /// test core's sync costs no WindowServer transaction (#1894).
    @MainActor
    final class InertBorderBackend: BorderOverlayBackend {
        let orderMode: BorderGeometry.Order

        init(orderMode: BorderGeometry.Order) {
            self.orderMode = orderMode
        }

        func update(
            geometry: BorderGeometry,
            colorHex: String,
            screen: NSScreen?,
            room: CGRect?
        ) {}
        func order(relativeTo windowNumber: CGWindowID) {}
        func hide() {}
    }
#endif
