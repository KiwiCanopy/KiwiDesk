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
/// floating windows get a ring only while focused, and transient
/// overlays (launchers/panels, #300) never do.
extension KiwiCore {
    func updateBorders() {
        let style = tiler.settings.borderStyle
        guard style.enabled, let space = activeSpace else {
            borders.sync([])
            return
        }
        // Layout slots identify the active space's tiled windows and
        // provide fallback geometry; drawing below uses each real
        // frame so apps that clamp their size still get an exact ring.
        let targets = tiler.calculatedFrames(state: state)
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
        let slots = space.windows.compactMap {
            id -> (id: WindowID, frame: CGRect)? in
            guard let frame = targets[id] ?? state.windows[id]?.frame
            else { return nil }
            return (id: id, frame: frame)
        }
        let chosen = Self.borderSpecs(
            style: style,
            focused: space.focused,
            slots: slots,
            floating: floating,
            overlays: overlays,
            isMonocle: space.mode == .monocle
        )
        // Draw each ring around the window's REAL frame (its
        // actual on-screen size, which an app may have clamped
        // larger than the slot), not the slot it was assigned.
        // Falls back to the slot only until the first AX echo.
        borders.sync(
            chosen.map { spec in
                BorderManager.Spec(
                    window: spec.window,
                    frame: state.windows[spec.window]?.frame
                        ?? spec.frame,
                    colorHex: spec.colorHex,
                    width: spec.width,
                    cornerStyle: spec.cornerStyle
                )
            }
        )
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
    /// #300); every other visible tiled slot only when
    /// `unfocusedEnabled` and the space isn't monocle. Overlays and
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
        // gets no ring; a focused user-floated standard window
        // still does.
        if !overlays.contains(focused) {
            specs.append(
                BorderManager.Spec(
                    window: focused,
                    frame: focusedFrame,
                    colorHex: style.focusedColor,
                    width: width,
                    cornerStyle: style.cornerStyle
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
