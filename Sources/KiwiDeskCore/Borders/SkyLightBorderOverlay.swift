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
    // The surface plumbing (create/reshape/draw/destroy) lives in
    // the `SkyLightBorderOverlay+Surface` extension (separate
    // file, 350-line ceiling), so this state is internal rather
    // than private.
    static let borderTags: UInt64 =
        (1 << 1) | (1 << 9) | (1 << 18)
    static let backingStoreBuffered: Int32 = 2
    static let orderOut: Int32 = 0
    static let orderAbove: Int32 = 1
    static let orderBelow: Int32 = -1
    static let parkedOrigin = CGPoint(x: -9_999, y: -9_999)

    /// Where this ring stacks (#357/#367). `above` keeps its own
    /// clean corner arc as the only visible edge and preserves
    /// child-window occlusion by pinning to the target's
    /// sub-level; `below` needs no such pinning — the target
    /// itself occludes the ring beneath it — so its re-stack is a
    /// single order-below transaction (see `order(relativeTo:)`).
    let orderMode: BorderGeometry.Order

    let connection: SkyLight.ConnectionID
    let targetWindow: CGWindowID
    var window: CGWindowID = 0
    /// Unsafe only so Swift 6's nonisolated `deinit` can release the
    /// retained CF object; all operational access remains MainActor.
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
        // Fire-and-forget: `move` commits a transaction whose ops
        // report no meaningful status, so it cannot fail in a way
        // worth a fallback (unlike create/reshape/draw above).
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
        // The `SLSTransaction*` mutators return no meaningful status
        // (JankyBorders fires them and only commits), so they are
        // best-effort: gating them on `.success` reads a junk register
        // and would falsely retire this backend to the AppKit
        // fallback. Only `makeTransaction` is load-bearing.
        if orderMode == .below {
            // Below-order needs none of the level/sub-level
            // pinning above-order re-asserts for popover
            // occlusion (#357): the target itself occludes a
            // ring beneath it, so one plain order-below op keeps
            // the re-stack churn-free (the jankyborders model —
            // the above path's per-sync sub-level transactions
            // are the suspected #361 flicker source).
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
        // Pin the ring into the target's exact sub-level band. A child
        // the OS stacks over the target (a popover, a sheet) sits at a
        // *higher* sub-level, so it keeps rendering above a
        // sub-level-pinned ring even though the ring is ordered above
        // the target itself. Without this pin, above-order paints over
        // child popups — the #320 regression below-order avoided
        // (#357).
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
        // Fire-and-forget mutators; only `makeTransaction` gates.
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

    /// Commits and releases the transaction. `SLSTransactionCommit`
    /// returns no meaningful status (JankyBorders ignores it), so this
    /// is fire-and-forget — a garbage return must not read as failure.
    private func commit(_ transaction: CFTypeRef) {
        _ = SkyLight.transactionCommit?(transaction, 0)
    }
}
