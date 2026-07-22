import AppKit

/// Drives the dead-end rubber-band on focus rings (#436).
///
/// Mirrors `AnimationEngine`: one `DisplayLinkDriver` per monitor,
/// started lazily on the first bump and stopped when its windows
/// settle. Each tick steps a window's `DeadEndBump` and feeds the
/// resulting offset to its `BorderOverlay.renderBump` — pure overlay
/// motion, never an AX write. Under Reduce Motion it drops the
/// offset entirely and pulses the ring's opacity instead.
@MainActor
final class BorderBumpAnimator {
    private struct Active {
        weak var overlay: BorderOverlay?
        var bump: DeadEndBump
        let reduceMotion: Bool
        var rmElapsed: TimeInterval
        let baseColorHex: String
        let display: DisplayID
        let onDone: @MainActor () -> Void
    }

    /// At most one bump per window — a repeat retargets it in place.
    private var active: [WindowID: Active] = [:]
    private var drivers: [DisplayID: DisplayLinkDriver] = [:]

    /// One opacity pulse for the Reduce-Motion substitution: dip to
    /// ~30% and back, no repeating strobe.
    private static let rmDuration: TimeInterval = 0.3
    private static let rmDip = 0.7

    /// Starts (or retargets) a bump on `window`'s ring. `impulse` is
    /// the offset toward the wall; `onDone` tears down a transient
    /// overlay once the cue settles.
    func flash(
        window: WindowID,
        overlay: BorderOverlay,
        impulse: CGVector,
        colorHex: String,
        screen: NSScreen,
        reduceMotion: Bool,
        onDone: @escaping @MainActor () -> Void
    ) {
        guard let display = screen.kiwiDisplay?.id else {
            onDone()
            return
        }
        if var existing = active[window] {
            // Retarget-in-place: re-impulse the live spring (or
            // restart the opacity pulse) rather than stack a second
            // animation, so key-repeat reads as one held press.
            existing.bump.reimpulse(offset: impulse)
            existing.rmElapsed = 0
            active[window] = existing
        } else {
            active[window] = Active(
                overlay: overlay,
                bump: DeadEndBump(
                    offset: reduceMotion ? .zero : impulse
                ),
                reduceMotion: reduceMotion,
                rmElapsed: 0,
                baseColorHex: colorHex,
                display: display,
                onDone: onDone
            )
        }
        startDriver(for: display, screen: screen)
    }

    private func startDriver(for display: DisplayID, screen: NSScreen) {
        if drivers[display] == nil {
            drivers[display] = DisplayLinkDriver(
                screen: screen
            ) { [weak self] dt in
                self?.tick(display: display, dt: dt)
            }
        }
        drivers[display]?.start()
    }

    private func tick(display: DisplayID, dt: TimeInterval) {
        let ids = active.keys.filter {
            active[$0]?.display == display
        }
        var finished: [WindowID] = []
        for id in ids {
            guard var a = active[id] else { continue }
            guard let overlay = a.overlay else {
                finished.append(id)
                continue
            }
            let settled =
                a.reduceMotion
                ? stepReduceMotion(&a, overlay: overlay, dt: dt)
                : stepBump(&a, overlay: overlay, dt: dt)
            if settled {
                finished.append(id)
            } else {
                active[id] = a
            }
        }
        for id in finished {
            active[id]?.onDone()
            active[id] = nil
        }
        if !active.values.contains(where: { $0.display == display }) {
            drivers[display]?.stop()
        }
    }

    private func stepBump(
        _ a: inout Active,
        overlay: BorderOverlay,
        dt: TimeInterval
    ) -> Bool {
        let settled = a.bump.step(dt: dt)
        overlay.renderBump(offset: a.bump.offset)
        return settled
    }

    private func stepReduceMotion(
        _ a: inout Active,
        overlay: BorderOverlay,
        dt: TimeInterval
    ) -> Bool {
        a.rmElapsed += dt
        let progress = min(1, a.rmElapsed / Self.rmDuration)
        // Single half-sine dip: 1 → (1 - dip) → 1 over the pulse.
        let alpha = 1 - Self.rmDip * sin(.pi * progress)
        overlay.renderBump(
            offset: .zero,
            colorHex: Self.dim(a.baseColorHex, alpha: alpha)
        )
        if progress >= 1 {
            // Restore the real stroke (nil colorHex → last real).
            overlay.renderBump(offset: .zero)
            return true
        }
        return false
    }

    /// `hex` with its alpha multiplied by `factor`, as `#RRGGBBAA`.
    static func dim(_ hex: String, alpha factor: Double) -> String {
        let base =
            NSColor(kiwiHex: hex).usingColorSpace(.sRGB)
            ?? NSColor(kiwiHex: hex)
        let byte = { (v: CGFloat) in
            Int((min(1, max(0, v)) * 255).rounded())
        }
        return String(
            format: "#%02X%02X%02X%02X",
            byte(base.redComponent),
            byte(base.greenComponent),
            byte(base.blueComponent),
            byte(base.alphaComponent * CGFloat(factor))
        )
    }
}
