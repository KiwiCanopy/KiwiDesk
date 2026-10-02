import AppKit
import CoreGraphics
import Foundation

/// Drives the focus-border overlays (#278). `updateBorders()`
/// snapshots the active space and hands the manager the desired
/// rings; the "who gets a ring" decision (`borderSpecs`) is a pure
/// `nonisolated` function so it stays actor-free and
/// unit-testable.
///
/// Every window gets its own ring when unfocused borders are
/// enabled — tiled, every member of an overflow cascade, and
/// floating, whether by flag or by a floating-mode space (#1286;
/// the ring sits behind its window, so an overlapped one shows
/// where it peeks out). Monocle is always focused-only because
/// only one window is visible; transient overlays
/// (launchers/panels, #300) and native-fullscreen windows
/// (display-filling — only the corners would show) never do.
extension KiwiCore {
    /// `reassertOrder` re-stacks every ring — the settle passes'
    /// job; a steady retile orders only rings that need it, the
    /// WindowServer reorder events keeping the rest (#1925).
    func updateBorders(reassertOrder: Bool = false) {
        let measured = tiler.meter.begin(.borders)  // #1508
        defer { measured() }
        // Global draw order (behind / front, #367) — set before the
        // enabled guard so a re-enable rebuilds on the right backend.
        borders.setDrawOrder(tiler.settings.borderStyle.drawOrder)
        // A window on an away Desktop keeps its dormant ring for
        // its return; borders off release them all.
        let alive =
            tiler.settings.borderStyle.enabled
            ? Set(state.windows.all.map(\.id))
                .union(state.awayWindows.keys)
            : []
        borders.sync(
            desiredBorderSpecs(),
            alive: alive,
            reassertOrder: reassertOrder
        )
    }

    /// Re-evaluates the ring set when one of OUR OWN windows
    /// gains or resigns key (#933 follow-up). The stand-down
    /// predicate in `desiredBorderSpecs` is only as live as its
    /// triggers: Sparkle's update alert can take key without
    /// producing a single `KiwiEvent` (nothing tracked
    /// changes), so no retile re-ran the specs and the stale
    /// focused ring stayed drawn behind the alert — the
    /// predicate was right and simply never re-asked (device
    /// QA, 2026-08-22). Both directions, so the ring also
    /// returns on dismiss without an app switch.
    /// `NotificationCenter.default` carries only this
    /// process's window notifications, so no sender filter is
    /// needed. Tokens live on `BorderManager`
    /// (`ownKeyWindowObservers`); the handler body is named so
    /// a test can drive the refresh without a real `NSWindow`.
    func wireOwnKeyWindowRefresh() {
        let names = [
            NSWindow.didBecomeKeyNotification,
            NSWindow.didResignKeyNotification,
        ]
        for name in names {
            let token = NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.ownKeyWindowDidChange()
                }
            }
            borders.ownKeyWindowObservers.append(token)
        }
    }

    /// The observer body: one cheap, idempotent spec rebuild.
    func ownKeyWindowDidChange() {
        updateBorders()
    }

    /// The rings the active space should show right now — the pure
    /// data-gathering half of `updateBorders`, split out so it can be
    /// asserted without spawning overlay panels. Empty when borders
    /// are disabled or no space is active.
    func desiredBorderSpecs() -> [BorderManager.Spec] {
        let style = tiler.settings.borderStyle
        guard style.enabled, let space = activeSpace else { return [] }
        // Layout slots identify the active space's tiled windows and
        // provide fallback geometry; drawing below uses each real
        // frame so apps that clamp their size still get an exact ring.
        let targets = tiler.calculatedFrames(state: state)
        // Tiled membership includes tiled-sticky travelers injected
        // into the active space (#414 v2). The focused window is the
        // same `focusAnchor` the App Bar / Scrolling / Monocle already
        // read (#431), so a keyboard focus that lands on a traveler
        // moves the ring onto it too — not only a mouse click.
        let tiled = state.effectiveTiledMembers(of: space)
        let travelers = tiled.filter { !space.windows.contains($0) }
        // Transient overlays (launchers, panels) never get a ring,
        // even while focused — see `borderSpecs` (#300). Scans
        // `space.windows` only by construction: an overlay is never
        // tiled, so it can never be a traveler.
        let overlays = Set(
            space.windows.filter {
                state.windows[$0]?.isTransientOverlay == true
            }
        )
        // Native-fullscreen windows never get one either: they
        // keep their home-space slot (no destroy fires), but fill
        // the display, so a ring would show only at the corners.
        // Travelers ARE included (a tiled-sticky window can go
        // fullscreen).
        let fullscreen = Set(
            (space.windows + travelers).filter {
                state.windows[$0]?.isFullscreen == true
            }
        )
        let slots = (space.windows + travelers).compactMap {
            id -> (id: WindowID, frame: CGRect)? in
            guard let frame = targets[id] ?? state.windows[id]?.frame
            else { return nil }
            return (id: id, frame: frame)
        }
        // While an own key window that is NOT the anchor is
        // active (Sparkle's update alert: the #929 flow
        // re-points state focus at the background survivor and
        // nothing re-points it at the alert), the anchor is
        // stale — the focused ring stands down, exactly as it
        // does for a focused launcher (#300/#933). An own key
        // window that IS the anchor (the Settings window)
        // keeps its ring. The ring reads the seam's NUMBER —
        // any own key window, deliberately broader than the
        // dialog class the raise reads (#935; the seam's doc
        // owns the split).
        let anchor = state.focusAnchor(of: space, tiled: tiled)
        let suppressed =
            eventLoop.ownKeyWindow().map { reading in
                UInt32(exactly: reading.number).map {
                    anchor?.raw != $0
                } ?? true
            } ?? false
        let chosen = Self.borderSpecs(
            style: style,
            focused: anchor,
            slots: slots,
            overlays: overlays,
            fullscreen: fullscreen,
            isMonocle: space.mode == .monocle,
            focusedRingSuppressed: suppressed,
            sheen: style.sheen
        )
        // Draw each ring around the window's REAL frame (its
        // actual on-screen size, which an app may have clamped
        // larger than the slot), not the slot it was assigned.
        // Falls back to the slot only until the first AX echo.
        return chosen.map { spec in
            BorderManager.Spec(
                window: spec.window,
                frame: state.windows[spec.window]?.frame
                    ?? spec.frame,
                colorHex: spec.colorHex,
                width: spec.width,
                cornerStyle: spec.cornerStyle,
                glowBlur: spec.glowBlur,
                sheen: spec.sheen
            )
        }
    }

    /// The rings to show for one space. Focused window always
    /// (when borders are on), unless it is a transient overlay
    /// (`overlays` — a launcher/panel that momentarily takes focus,
    /// #300) or in native fullscreen (`fullscreen` — it fills the
    /// display, a ring would show only at the corners); every
    /// other visible slot — tiled or floating — only when
    /// `unfocusedEnabled` and the space isn't monocle. Overlays and
    /// fullscreen windows never get a ring. Cascade members
    /// remain independent: border presentation must not change the
    /// shared pile semantics used by navigation and swap. Pure over
    /// the flat slot list — no `self`, no AX.
    nonisolated static func borderSpecs(
        style: BorderStyle,
        focused: WindowID?,
        slots: [(id: WindowID, frame: CGRect)],
        overlays: Set<WindowID>,
        fullscreen: Set<WindowID>,
        isMonocle: Bool,
        // No default (#878's defaulted-parameter lesson): a new
        // caller must answer whether an own untracked key window
        // holds the real focus, or it silently restores the
        // stale-anchor ring with every suite green.
        focusedRingSuppressed: Bool,
        // The focused ring alone wears it, as with glow (#1644).
        sheen: CGFloat
    ) -> [BorderManager.Spec] {
        guard style.enabled, let focused,
            let focusedFrame = slots.first(where: {
                $0.id == focused
            })?.frame
        else { return [] }
        let width = style.clampedWidth
        var specs: [BorderManager.Spec] = []
        // A focused transient overlay (Spotlight/Raycast/Alfred)
        // or native-fullscreen window gets no ring; a focused
        // user-floated standard window still does. Suppression
        // (#933: an own untracked key window holds the real
        // focus) drops it too — the stale anchor joins the
        // unfocused rings below instead.
        if !overlays.contains(focused),
            !fullscreen.contains(focused),
            !focusedRingSuppressed
        {
            specs.append(
                BorderManager.Spec(
                    window: focused,
                    frame: focusedFrame,
                    colorHex: style.focusedColor,
                    width: width,
                    cornerStyle: style.cornerStyle,
                    glowBlur: style.glowBlur(focused: true),
                    sheen: sheen
                )
            )
        }
        guard style.unfocusedEnabled, !isMonocle else {
            return specs
        }
        for slot in slots
        where (focusedRingSuppressed || slot.id != focused)
            && !overlays.contains(slot.id)
            && !fullscreen.contains(slot.id)
        {
            specs.append(
                BorderManager.Spec(
                    window: slot.id,
                    frame: slot.frame,
                    colorHex: style.unfocusedColor,
                    width: width,
                    cornerStyle: style.cornerStyle,
                    glowBlur: style.glowBlur(focused: false)
                )
            )
        }
        return specs
    }
}
