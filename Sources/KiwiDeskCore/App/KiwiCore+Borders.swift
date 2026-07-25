import CoreGraphics

/// Drives the focus-border overlays (#278). `updateBorders()`
/// snapshots the active space and hands the manager the desired
/// rings; the "who gets a ring" decision (`borderSpecs`) is a pure
/// `nonisolated` function so it stays actor-free and
/// unit-testable.
///
/// Every tiled window gets its own ring when unfocused borders are
/// enabled, including every member of an overflow cascade. Monocle
/// is always focused-only because only one window is visible;
/// floating windows get a ring only while focused; transient
/// overlays (launchers/panels, #300) and native-fullscreen
/// windows (display-filling — only the corners would show)
/// never do.
extension KiwiCore {
    func updateBorders() {
        // Global draw order (behind / front, #367) — set before the
        // enabled guard so a re-enable rebuilds on the right backend.
        borders.setDrawOrder(tiler.settings.borderStyle.drawOrder)
        borders.sync(desiredBorderSpecs())
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
        let tiled = state.effectiveTiledMembers(
            of: space,
            activeSpace: activeSpace?.id
        )
        let travelers = tiled.filter { !space.windows.contains($0) }
        let floating = Set(
            space.windows.filter {
                state.windows[$0]?.isFloating == true
            }
        )
        // Transient overlays (launchers, panels) never get a ring,
        // even while focused — see `borderSpecs` (#300).
        let overlays = Set(
            space.windows.filter {
                state.windows[$0]?.isTransientOverlay == true
            }
        )
        // Native-fullscreen windows never get one either: they
        // keep their home-space slot (no destroy fires), but fill
        // the display, so a ring would show only at the corners.
        // Travelers ARE included here (a tiled-sticky window can go
        // fullscreen) — unlike `floating`/`overlays` above, which
        // scan `space.windows` only *by construction*: a floating or
        // transient-overlay window is never tiled, so it can never be
        // a traveler. Don't "harmonize" the three scopes into one —
        // only fullscreen needs the traveler union.
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
        let chosen = Self.borderSpecs(
            style: style,
            focused: state.focusAnchor(of: space, tiled: tiled),
            slots: slots,
            floating: floating,
            overlays: overlays,
            fullscreen: fullscreen,
            isMonocle: space.mode == .monocle
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
                glow: spec.glow
            )
        }
    }

    /// WindowServer can briefly order the swap target out while a
    /// drag/drop retile and focus raise overlap. Its hide notification
    /// hides that target's ring, but macOS does not always send a
    /// matching unhide. Re-assert the complete desired ring set after
    /// the swap animation (or one short event turn when unanimated).
    func scheduleBorderDropReconcile() {
        let animationMS =
            tiler.animation.activeCount > 0
            ? tiler.settings.animations.durationMS : 0
        deferred.schedule(
            .borderDropSettle,
            after: .milliseconds(animationMS + 50)
        ) { [weak self] in
            self?.updateBorders()
        }
    }

    /// The rings to show for one space. Focused window always
    /// (when borders are on), unless it is a transient overlay
    /// (`overlays` — a launcher/panel that momentarily takes focus,
    /// #300) or in native fullscreen (`fullscreen` — it fills the
    /// display, a ring would show only at the corners); every
    /// other visible tiled slot only when `unfocusedEnabled` and
    /// the space isn't monocle. Overlays, fullscreen windows, and
    /// unfocused floating windows never get a ring. Cascade members
    /// remain independent: border presentation must not change the
    /// shared pile semantics used by navigation and swap. Pure over
    /// the flat slot list — no `self`, no AX.
    nonisolated static func borderSpecs(
        style: BorderStyle,
        focused: WindowID?,
        slots: [(id: WindowID, frame: CGRect)],
        floating: Set<WindowID>,
        overlays: Set<WindowID>,
        fullscreen: Set<WindowID>,
        isMonocle: Bool
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
        // user-floated standard window still does.
        if !overlays.contains(focused),
            !fullscreen.contains(focused)
        {
            specs.append(
                BorderManager.Spec(
                    window: focused,
                    frame: focusedFrame,
                    colorHex: style.focusedColor,
                    width: width,
                    cornerStyle: style.cornerStyle,
                    // Focused ring only — a bloom on every unfocused
                    // ring undercuts the one it should make pop.
                    glow: style.glow
                )
            )
        }
        guard style.unfocusedEnabled, !isMonocle else {
            return specs
        }
        for slot in slots
        where slot.id != focused
            && !floating.contains(slot.id)
            && !overlays.contains(slot.id)
            && !fullscreen.contains(slot.id)
        {
            specs.append(
                BorderManager.Spec(
                    window: slot.id,
                    frame: slot.frame,
                    colorHex: style.unfocusedColor,
                    width: width,
                    cornerStyle: style.cornerStyle
                )
            )
        }
        return specs
    }
}
