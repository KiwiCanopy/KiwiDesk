import AppKit
import CoreFoundation
import CoreGraphics

/// The raw WindowServer surface behind `SkyLightBorderOverlay`:
/// window creation, shape, stroke drawing, and teardown. Split
/// from the transaction/lifecycle half for the 350-line ceiling;
/// order-agnostic — both `above` and `below` rings share it.
extension SkyLightBorderOverlay {
    func createWindow(frame: CGRect, scale: CGFloat) -> Bool {
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
        // Pin the ring to its target's own space (both orders): a
        // space-unassigned SkyLight window reads as all-spaces, so
        // Mission Control would float it over the overview instead
        // of leaving it behind on the swipe, the way jankyborders'
        // pinned borders vanish instantly. Pinning is the ring's
        // ONLY Mission Control hide now that the observer is gone, so
        // if no space resolves, retire this backend — `update()`
        // destroys this partial window and the facade falls back to
        // the AppKit `.transient` ring, which self-hides. No silent
        // unpinned (floating-in-MC) ring can survive.
        guard
            SkyLight.pinWindow(
                newID,
                toSpaceOf: targetWindow,
                connection: connection
            )
        else { return false }
        return true
    }

    func reshape(to frame: CGRect) -> Bool {
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

    func setResolution(_ scale: CGFloat) -> Bool {
        SkyLight.setWindowResolution?(
            connection,
            window,
            Double(scale)
        ) == .success
    }

    func draw(
        _ geometry: BorderGeometry,
        colorHex: String
    ) -> Bool {
        guard let context else { return false }
        let bounds = CGRect(
            origin: .zero,
            size: geometry.overlayFrame.size
        )
        // The stroke sits `glowMargin` in from the grown frame so
        // the ring stays put and the extra margin is bloom room
        // (#358); `glowMargin` is 0 for a plain ring, so this is the
        // original inset then.
        let inset = geometry.glowMargin + geometry.lineWidth / 2
        let pathRect = bounds.insetBy(dx: inset, dy: inset)
        context.clear(bounds)
        // Always the crisp ring: a glow ring never renders here —
        // the facade swaps it to the AppKit backend (#533), whose
        // `CAShapeLayer` shadow blooms correctly, because this
        // WindowServer-backed context drops any shadow colour to
        // default black-at-low-alpha (grey), and painted-falloff
        // substitutes banded or clipped on device. If glow
        // geometry ever does arrive, the inset still holds and
        // only the bloom is missing.
        paintRing(
            context,
            pathRect: pathRect,
            geometry: geometry,
            colorHex: colorHex
        )
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

    /// A plain crisp ring: stroke the centerline path at the full
    /// line width. The no-glow path, and identical to the pre-#358
    /// draw.
    private func paintRing(
        _ context: CGContext,
        pathRect: CGRect,
        geometry: BorderGeometry,
        colorHex: String
    ) {
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
    }

    func makeRegion(_ rect: CGRect) -> CFTypeRef? {
        guard let create = SkyLight.newRegionWithRect else {
            return nil
        }
        var rect = rect
        var region: Unmanaged<CFTypeRef>?
        guard create(&rect, &region) == .success else { return nil }
        return region?.takeRetainedValue()
    }

    func destroyWindow() {
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
