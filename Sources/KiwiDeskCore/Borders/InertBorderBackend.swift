import AppKit

#if DEBUG
    /// A ring backend that draws nothing and owns no window: every
    /// `makeTestCore` ring takes it (#1894), so a fixture's sync
    /// costs no WindowServer transaction. Suites that test the panel
    /// build `AppKitBorderOverlay` themselves.
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
