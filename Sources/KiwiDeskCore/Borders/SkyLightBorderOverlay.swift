import AppKit
import CoreFoundation
import CoreGraphics

/// A focus ring drawn directly into a SkyLight window (#285 Tier 2).
/// Origin-only updates are one WindowServer transaction; resizing or
/// restyling rebuilds the shape/context content. Any failed private
/// operation retires this backend and lets `BorderOverlay` replay the
/// latest state through its AppKit panel.
@MainActor
final class SkyLightBorderOverlay: BorderOverlayBackend {
    private static let borderTags: UInt64 =
        (1 << 1) | (1 << 9) | (1 << 18)
    private static let backingStoreBuffered: Int32 = 2
    private static let orderOut: Int32 = 0
    private static let orderBelow: Int32 = -1
    private static let parkedOrigin = CGPoint(x: -9_999, y: -9_999)

    private let connection: SkyLight.ConnectionID
    private let targetWindow: CGWindowID
    private var window: CGWindowID = 0
    /// Unsafe only so Swift 6's nonisolated `deinit` can release the
    /// retained CF object; all operational access remains MainActor.
    nonisolated(unsafe) private var context: CGContext?
    private var geometry: BorderGeometry?
    private var colorHex = ""
    private var scale: CGFloat = 0

    init?(targetWindow: CGWindowID) {
        guard SkyLight.borderRenderingAvailable,
            let connection = SkyLight.connection
        else { return nil }
        self.connection = connection
        self.targetWindow = targetWindow
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
            // JankyBorders likewise recreates its raw window when
            // resolution changes: the CGContext owns that surface's
            // pixel density, so mutating it in place is not reliable.
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
        // Match JankyBorders' split: a full update establishes the
        // inverse transform that anchors the raw surface, while a
        // move-only update is one cheap origin transaction.
        let resetTransform = previous == nil || needsRedraw
        guard
            move(
                to: geometry.overlayFrame.origin,
                resetTransform: resetTransform
            )
        else {
            destroyWindow()
            return false
        }
        if recreatedForScale && !order(behind: targetWindow) {
            destroyWindow()
            return false
        }
        return true
    }

    func order(behind windowNumber: CGWindowID) -> Bool {
        guard window != 0, windowNumber == targetWindow,
            let transaction = makeTransaction()
        else { return false }
        var level: Int64 = 0
        guard
            SkyLight.getWindowLevel?(
                connection,
                targetWindow,
                &level
            ) == .success,
            level >= Int64(Int32.min), level <= Int64(Int32.max),
            SkyLight.transactionLevel?(
                transaction,
                window,
                Int32(level)
            ) == .success,
            SkyLight.transactionOrder?(
                transaction,
                window,
                Self.orderBelow,
                targetWindow
            ) == .success
        else { return false }
        return commit(transaction)
    }

    func hide() -> Bool {
        guard window != 0 else { return true }
        guard let transaction = makeTransaction(),
            SkyLight.transactionOrder?(
                transaction,
                window,
                Self.orderOut,
                targetWindow
            ) == .success
        else { return false }
        return commit(transaction)
    }

    private func createWindow(frame: CGRect, scale: CGFloat) -> Bool {
        guard
            let region = makeRegion(
                CGRect(origin: .zero, size: frame.size)
            ), let newWindow = SkyLight.newWindow
        else { return false }
        var newID: CGWindowID = 0
        guard
            newWindow(
                connection,
                Self.backingStoreBuffered,
                Float(Self.parkedOrigin.x),
                Float(Self.parkedOrigin.y),
                region,
                &newID
            ) == .success,
            newID != 0
        else { return false }
        window = newID

        var tags = Self.borderTags
        guard
            SkyLight.setWindowTags?(
                connection,
                newID,
                &tags,
                64
            ) == .success,
            SkyLight.setWindowOpacity?(
                connection,
                newID,
                false
            ) == .success,
            SkyLight.setShadowParameters?(
                connection,
                newID,
                0,
                0,
                0,
                0
            ) == .success,
            setResolution(scale),
            let created = SkyLight.windowContextCreate?(
                connection,
                newID,
                nil
            )
        else { return false }
        context = created.takeRetainedValue()
        self.scale = scale
        return true
    }

    private func reshape(to frame: CGRect) -> Bool {
        guard
            let region = makeRegion(
                CGRect(origin: .zero, size: frame.size)
            ),
            SkyLight.windowFreeze?(
                connection,
                window,
                nil
            ) == .success,
            SkyLight.setWindowShape?(
                connection,
                window,
                Float(frame.origin.x),
                Float(frame.origin.y),
                region
            ) == .success
        else { return false }
        return true
    }

    private func setResolution(_ scale: CGFloat) -> Bool {
        SkyLight.setWindowResolution?(
            connection,
            window,
            Double(scale)
        ) == .success
    }

    private func draw(
        _ geometry: BorderGeometry,
        colorHex: String
    ) -> Bool {
        guard let context else { return false }
        let bounds = CGRect(
            origin: .zero,
            size: geometry.overlayFrame.size
        )
        let pathRect = bounds.insetBy(
            dx: geometry.lineWidth / 2,
            dy: geometry.lineWidth / 2
        )
        context.clear(bounds)
        context.setLineWidth(geometry.lineWidth)
        context.setStrokeColor(NSColor(kiwiHex: colorHex).cgColor)
        context.addPath(
            CGPath(
                roundedRect: pathRect,
                cornerWidth: geometry.cornerRadius,
                cornerHeight: geometry.cornerRadius,
                transform: nil
            )
        )
        context.strokePath()
        context.flush()
        guard
            SkyLight.flushWindowContent?(
                connection,
                window,
                nil
            ) == .success
        else { return false }
        // Harmless when the window was not frozen; required after a
        // shape resize so the fresh surface becomes visible at once.
        return SkyLight.windowThaw?(
            connection,
            window
        ) == .success
    }

    private func move(
        to origin: CGPoint,
        resetTransform: Bool
    ) -> Bool {
        guard let transaction = makeTransaction(),
            SkyLight.transactionMove?(
                transaction,
                window,
                origin
            ) == .success
        else { return false }
        if resetTransform {
            let transform = CGAffineTransform(
                translationX: -origin.x,
                y: -origin.y
            )
            guard
                SkyLight.transactionTransform?(
                    transaction,
                    window,
                    0,
                    0,
                    transform
                ) == .success
            else { return false }
        }
        return commit(transaction)
    }

    private func makeTransaction() -> CFTypeRef? {
        SkyLight.transactionCreate?(connection)?.takeRetainedValue()
    }

    private func commit(_ transaction: CFTypeRef) -> Bool {
        SkyLight.transactionCommit?(
            transaction,
            0
        ) == .success
    }

    private func makeRegion(_ rect: CGRect) -> CFTypeRef? {
        guard let create = SkyLight.newRegionWithRect else {
            return nil
        }
        var rect = rect
        var region: Unmanaged<CFTypeRef>?
        guard create(&rect, &region) == .success else { return nil }
        return region?.takeRetainedValue()
    }

    private func destroyWindow() {
        context = nil
        if window != 0 {
            _ = SkyLight.releaseWindow?(connection, window)
        }
        window = 0
        geometry = nil
        colorHex = ""
        scale = 0
    }
}
