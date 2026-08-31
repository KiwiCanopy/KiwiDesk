import AppKit
import CoreFoundation
import CoreGraphics

/// Focus ring overlay rendered directly via SkyLight window (#285 Tier 2).
@MainActor
final class SkyLightBorderOverlay: BorderOverlayBackend {
    static let borderTags: UInt64 =
        (1 << 1) | (1 << 9) | (1 << 18)

    /// SkyLight contexts drop shadow colours (#533); glow uses AppKit.
    let rendersGlow = false
    static let backingStoreBuffered: Int32 = 2
    static let orderOut: Int32 = 0
    static let orderAbove: Int32 = 1
    static let orderBelow: Int32 = -1
    static let parkedOrigin = CGPoint(x: -9_999, y: -9_999)

    /// Window stacking relative position (#357, #367).
    let orderMode: BorderGeometry.Order

    let connection: SkyLight.ConnectionID
    let targetWindow: CGWindowID
    var window: CGWindowID = 0
    nonisolated(unsafe) var context: CGContext?
    var geometry: BorderGeometry?
    var colorHex = ""
    var scale: CGFloat = 0

    init?(
        targetWindow: CGWindowID,
        order: BorderGeometry.Order = .above
    ) {
        guard SkyLight.borderRenderingAvailable,
            let connection = SkyLight.connection
        else { return nil }
        self.connection = connection
        self.targetWindow = targetWindow
        orderMode = order
    }

    deinit {
        context = nil
        if window != 0 {
            _ = SkyLight.releaseWindow?(connection, window)
        }
    }

    func update(
        geometry: BorderGeometry,
        colorHex: String,
        screen: NSScreen?
    ) -> Bool {
        let previous = self.geometry
        let nextScale = screen?.backingScaleFactor ?? 2
        let recreatedForScale = window != 0 && scale != nextScale
        if recreatedForScale {
            _ = hide()
            destroyWindow()
        }
        if window == 0,
            !createWindow(
                frame: geometry.overlayFrame,
                scale: nextScale
            )
        {
            destroyWindow()
            return false
        }

        let sizeChanged =
            self.geometry?.overlayFrame.size
            != geometry.overlayFrame.size
        let needsRedraw =
            sizeChanged
            || previous?.lineWidth != geometry.lineWidth
            || previous?.cornerRadius != geometry.cornerRadius
            || previous?.glowMargin != geometry.glowMargin
            || self.colorHex != colorHex

        if sizeChanged && !reshape(to: geometry.overlayFrame) {
            destroyWindow()
            return false
        }
        self.geometry = geometry
        self.colorHex = colorHex
        scale = nextScale
        if needsRedraw && !draw(geometry, colorHex: colorHex) {
            destroyWindow()
            return false
        }
        let resetTransform = previous == nil || needsRedraw
        move(
            to: geometry.overlayFrame.origin,
            resetTransform: resetTransform
        )
        if recreatedForScale && !order(relativeTo: targetWindow) {
            destroyWindow()
            return false
        }
        return true
    }

    func order(relativeTo windowNumber: CGWindowID) -> Bool {
        guard window != 0, windowNumber == targetWindow,
            let transaction = makeTransaction()
        else { return false }
        if orderMode == .below {
            // Below-order relies on target window occlusion (#357, #361).
            _ = SkyLight.transactionOrder?(
                transaction,
                window,
                Self.orderBelow,
                targetWindow
            )
            commit(transaction)
            return true
        }
        var level: Int64 = 0
        if SkyLight.getWindowLevel?(connection, targetWindow, &level)
            == .success,
            level >= Int64(Int32.min), level <= Int64(Int32.max)
        {
            _ = SkyLight.transactionLevel?(
                transaction,
                window,
                Int32(level)
            )
        }
        // Pins ring into target's sub-level to prevent popup occlusion
        // (#320, #357).
        let subLevel =
            SkyLight.getWindowSubLevel?(connection, targetWindow) ?? 0
        _ = SkyLight.transactionSubLevel?(transaction, window, subLevel)
        _ = SkyLight.transactionOrder?(
            transaction,
            window,
            Self.orderAbove,
            targetWindow
        )
        commit(transaction)
        return true
    }

    func hide() -> Bool {
        guard window != 0 else { return true }
        guard let transaction = makeTransaction() else { return false }
        _ = SkyLight.transactionOrder?(
            transaction,
            window,
            Self.orderOut,
            targetWindow
        )
        commit(transaction)
        return true
    }

    private func move(
        to origin: CGPoint,
        resetTransform: Bool
    ) {
        guard let transaction = makeTransaction() else { return }
        _ = SkyLight.transactionMove?(transaction, window, origin)
        if resetTransform {
            let transform = CGAffineTransform(
                translationX: -origin.x,
                y: -origin.y
            )
            _ = SkyLight.transactionTransform?(
                transaction,
                window,
                0,
                0,
                transform
            )
        }
        commit(transaction)
    }

    private func makeTransaction() -> CFTypeRef? {
        SkyLight.transactionCreate?(connection)?.takeRetainedValue()
    }

    /// Commits SkyLight window server transaction.
    private func commit(_ transaction: CFTypeRef) {
        _ = SkyLight.transactionCommit?(transaction, 0)
    }
}
