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
        // While an own key window that is NOT the anchor is
        // active (Sparkle's update alert: the #929 flow
        // re-points state focus at the background survivor and
        // nothing re-points it at the alert), the anchor is
        // stale — the focused ring stands down, exactly as it
        // does for a focused launcher (#300/#933). An own key
        // window that IS the anchor (the Settings window)
        // keeps its ring.
        let anchor = state.focusAnchor(of: space, tiled: tiled)
        let suppressed =
            eventLoop.ownKeyWindowNumber().map { number in
                UInt32(exactly: number).map {
                    anchor?.raw != $0
                } ?? true
            } ?? false
        let chosen = Self.borderSpecs(
            style: style,
            focused: anchor,
            slots: slots,
            floating: floating,
            overlays: overlays,
            fullscreen: fullscreen,
            isMonocle: space.mode == .monocle,
            focusedRingSuppressed: suppressed
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
                glowBlur: spec.glowBlur
            )
        }
    }

    /// How long after the animation clock settles the overlays are
    /// re-synced from real window state (#596). Not a guess at the
    /// motion's length — the settle signal already tells us that —
    /// but at how long a slow-AX app keeps applying queued frames
    /// past it (100–300 ms on Electron/WebKit; 213 ms measured on
    /// device for a frozen-then-resumed app). Reading sooner reads
    /// bounds the app has not caught up to, which is the backward
    /// snap this issue is about; reading later costs nothing in
    /// the common case, because the post-settle AX echoes are
    /// already walking the overlay onto the real frame — this pass
    /// is the backstop for the app that sends no echo at all.
    /// No mutable seam sits beside it: `runBorderResync` is
    /// directly callable, so a test drives the body rather than
    /// waiting the delay out.
    static let borderResyncDelayMS = 300

    /// WindowServer can briefly order the swap target out while a
    /// drag/drop retile and focus raise overlap. Its hide
    /// notification hides that target's ring, but macOS does not
    /// always send a matching unhide. Re-assert the complete
    /// desired ring set once the swap animation is well under way
    /// (or one short event turn later when nothing animates).
    ///
    /// This is the VISIBILITY pass, and it is deliberately early:
    /// `sync`'s trailing `order(relativeTo:)` is what un-hides a
    /// ring, so the sooner it runs the shorter a wrongly-hidden
    /// ring stays invisible. Landing mid-flight used to make it
    /// the backward snap of #596 item 3 — it no longer can,
    /// because `FollowSource.syncFrame` holds the geometry of a
    /// window OUR OWN animation is driving, so this pass
    /// re-orders and un-hides without moving that window's ring.
    /// (It still re-reads state for every non-animating ring in
    /// the space — the same thing the unconditional
    /// `updateBorders()` at the end of every `retile()` does.)
    ///
    /// That is why both passes exist: this one restores
    /// VISIBILITY early and cannot fix an animating window's
    /// geometry; `scheduleBorderResync` fixes GEOMETRY late and
    /// would be far too slow for a hidden ring. Separate deferred
    /// keys, so neither can cancel the other.
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

    /// Re-syncs both overlay families from real window state a
    /// grace after the last animation ends — the heal for a window
    /// whose app accepted no AX write during the flight (#596
    /// item 2). The ring rode our commanded per-tick frames to the
    /// target while the window never moved, and with no echo and
    /// no WindowServer event there is nothing else to correct it;
    /// this pass reads the state the window actually has and glues
    /// the ring and mark back onto it.
    func scheduleBorderResync() {
        deferred.schedule(
            .borderResync,
            after: .milliseconds(Self.borderResyncDelayMS)
        ) { [weak self] in
            self?.runBorderResync()
        }
    }

    /// The re-sync body. Named rather than inlined so a test can
    /// drive it directly instead of waiting out the grace.
    ///
    /// Deliberately UNGATED on the animation count. The obvious
    /// guard — bail if something started animating inside the
    /// grace — discards the whole pass because of ONE window,
    /// stranding every other window that did settle. Nothing is
    /// bought by it: `FollowSource.syncFrame` already refuses to
    /// move a window our animation is driving, per window, which
    /// is what the count was standing in for. That is the general
    /// shape — never gate on the global count as a proxy for a
    /// per-window question. (Waiting on the count for a genuinely
    /// global precondition is a different thing and stays
    /// correct: the z-order restore and the deferred focus raise
    /// both do it, because a raise issued while any frames are
    /// still landing arrives late on slow apps.)
    ///
    /// The cost of running early is one read of a window that
    /// settled seconds ago, and the in-flight animation's own
    /// settle arms another pass behind it.
    ///
    /// Ungating does NOT, by itself, survive an animation that
    /// never settles: the arming path sits behind the same
    /// signal — `notifyIfIdle` only fires `onAllAnimationsEnded`
    /// at `activeCount == 0` — so this pass would never be
    /// scheduled, gate or no gate, and the same held for the
    /// deferred focus raise and the z-order restore. That was
    /// always the engine's to fix, and #599 fixed the known
    /// cause; the shape of the exposure is why this stays
    /// ungated rather than growing a second guard.
    func runBorderResync() {
        updateBorders()
        updateStickyMarks()
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
        isMonocle: Bool,
        // No default (#878's defaulted-parameter lesson): a new
        // caller must answer whether an own untracked key window
        // holds the real focus, or it silently restores the
        // stale-anchor ring with every suite green.
        focusedRingSuppressed: Bool
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
                    // Focused ring only — a bloom on every unfocused
                    // ring undercuts the one it should make pop.
                    glowBlur: style.resolvedGlowBlur
                )
            )
        }
        guard style.unfocusedEnabled, !isMonocle else {
            return specs
        }
        for slot in slots
        where (focusedRingSuppressed || slot.id != focused)
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
