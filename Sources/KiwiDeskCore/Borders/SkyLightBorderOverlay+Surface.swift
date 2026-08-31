import AppKit
import CoreFoundation
import CoreGraphics

/// Raw SkyLight WindowServer surface management for border overlay.
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
        // Pin ring to target window Space for Mission Control visibility.
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
        // Inset centerline path by glowMargin + lineWidth / 2 (#358).
        let inset = geometry.glowMargin + geometry.lineWidth / 2
        let pathRect = bounds.insetBy(dx: inset, dy: inset)
        context.clear(bounds)
        // Draw crisp ring (glow swaps to AppKit backend, #533).
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
        return SkyLight.windowThaw?(
            connection,
            window
        ) == .success
    }

    /// Strokes plain crisp ring path at full line width (#358).
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
