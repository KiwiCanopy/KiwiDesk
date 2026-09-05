import AppKit
import CoreGraphics

extension KiwiCore {
    /// Flashes the refusal pill on `window` (#933) with `text`,
    /// and the glyph `refusal`'s own case picks (#1260) — the
    /// two channels come from one value so they cannot disagree.
    @discardableResult
    private func flashSizeLimitPill(
        _ window: WindowID,
        _ refusal: ResizeRefusal,
        text: String
    ) -> Bool {
        guard
            let frame = tiler.calculatedFrames(state: state)[window]
                ?? state.windows[window]?.frame
        else { return false }
        return borders.flashSizeLimitPill(
            window: window,
            frame: frame,
            text: text,
            symbol: refusal.pillSymbol
        )
    }

    /// The audible half of a refusal (#1255): a drawn pill may
    /// also sound, which is what the toggle has always claimed
    /// to control and now does.
    ///
    /// The hotkey-fire gate is inherited deliberately (#184): a
    /// resize driven from the CLI or IPC must not make the
    /// user's Mac beep at a script. And every caller has already
    /// ended a held run, so a chord sounds ONCE per hold rather
    /// than per frame — which is what makes sounding a real
    /// refusal safe where sounding every `.fail` never was.
    func soundRefusal() {
        guard keys.isFiring, tiler.settings.refusalSound
        else { return }
        NSSound.beep()
    }

    /// The one gate between a drawing and its sound: pass what
    /// the drawing RETURNED, never the fact that it was asked
    /// (#1255, `RefusalCueSeamTests`). Both primitives decline
    /// silently — no `privateRuntimeStarted`, no mark overlay —
    /// and a sound outrunning its pill is the invisible-refusal
    /// defect this change removed. It matters most for the
    /// sticky family, whose pill is gated on `sticky.mark`: with
    /// the mark off those refusals draw nothing, and say
    /// nothing.
    func soundIfDrawn(_ drew: Bool) {
        if drew { soundRefusal() }
    }

    /// The one entry every size-limit cue takes to reach the
    /// border seam: it also ends a held keyboard run (#1056), so
    /// a refusal pills once per hold rather than per frame. A new
    /// cue function routes here — `HoldGlideEligibilitySeamTests` pins
    /// this as the only production caller of
    /// `borders.onResizeRefusal`, which is what makes "a cue
    /// stops the run" structural rather than a line to remember.
    private func cueResizeRefusal(_ refusal: ResizeRefusal) {
        keys.noteResizeRefusal()
        borders.onResizeRefusal(refusal)
    }

    /// The zone has no parameter on the asked axis (#1255): a
    /// refusal like any other, so it draws and sounds through
    /// the one funnel. It replaces `cueUnsupportedCommand`,
    /// which cued by SOUND ALONE and so was the one refusal a
    /// user could not see — invisible with the toggle off, and
    /// invisible to anyone who does not hear it.
    func refuseAxisAbsent(_ window: WindowID, axis: String) {
        let refusal = ResizeRefusal.noAxisHere(window)
        cueResizeRefusal(refusal)
        soundIfDrawn(
            flashSizeLimitPill(
                window,
                refusal,
                text: axis == "y"
                    ? L(
                        "resize.no_height_here",
                        "This zone divides widths, not heights"
                    )
                    : L(
                        "resize.no_width_here",
                        "This zone divides heights, not widths"
                    )
            )
        )
    }

    /// The focused window is alone in the group this axis
    /// divides (#1258) — the resize has a parameter but nothing
    /// to move it against. Silent before this, at four sites
    /// across three layouts, which read as "the shortcut is
    /// broken" rather than "there is one window here".
    ///
    /// One sentence for all four deliberately: it states the
    /// fact the user can see (this window fills its zone) and
    /// claims nothing about the other axis, which sometimes
    /// works and sometimes does not. The layout-specific
    /// guidance stays in the CLI/IPC error string, which is a
    /// machine contract and free to be long (core-boundaries).
    func refuseNothingToDivide(_ window: WindowID) {
        let refusal = ResizeRefusal.nothingToDivide(window)
        cueResizeRefusal(refusal)
        soundIfDrawn(
            flashSizeLimitPill(
                window,
                refusal,
                text: L(
                    "resize.fills_its_zone",
                    "This window fills its zone"
                )
            )
        )
    }

    /// The layout has no resizing at all (#1255): monocle, grid
    /// and floating. A correct no-op — macOS's own full-screen
    /// exposes no resize either — but a perceivable one, and it
    /// is the MOST reachable refusal in the feature, not the
    /// least: any resize press in one of those three arrives
    /// here. It cued by sound alone until now.
    ///
    /// An empty space cues nothing: every refusal is drawn ON a
    /// window, so with no focus there is nothing to draw and
    /// nothing to sound beside it.
    func refuseResizeUnsupported(in space: Space) {
        guard let window = space.focused else { return }
        let refusal = ResizeRefusal.layoutHasNoResize(window)
        cueResizeRefusal(refusal)
        soundIfDrawn(
            flashSizeLimitPill(
                window,
                refusal,
                text: L(
                    "resize.layout_has_none",
                    "This layout has no resizing"
                )
            )
        )
    }

    /// Triggers both the DeadEndBump rubber-band on the focus ring
    /// and the minimum-size refusal pill when a shrink attempt
    /// hits the window's effective minimum size limit (#933).
    /// Fires on the first attempt the clamp truncates — landing
    /// ON the minimum included — not only once already there.
    func refuseShrinkAtMinimum(_ window: WindowID, axis: String) {
        let refusal = ResizeRefusal.ownMinimum(window)
        cueResizeRefusal(refusal)
        let direction: Direction = axis == "y" ? .down : .right
        flashDeadEnd(window, direction: direction)
        soundIfDrawn(
            flashSizeLimitPill(
                window,
                refusal,
                text: L(
                    "resize.min_size_reached",
                    "Minimum window size reached"
                )
            )
        )
    }

    /// Cues a grow refused at the window's own learned
    /// app-enforced maximum (#1055) — `refuseShrinkAtMinimum`'s
    /// mirror at the other end. One pill only: the limit is the
    /// resized window's own app, so there is no second window
    /// to mark, and the bump stays on the gesture that hit the
    /// wall.
    func refuseGrowAtMaximum(_ window: WindowID, axis: String) {
        let refusal = ResizeRefusal.ownMaximum(window)
        cueResizeRefusal(refusal)
        let direction: Direction = axis == "y" ? .down : .right
        flashDeadEnd(window, direction: direction)
        soundIfDrawn(
            flashSizeLimitPill(
                window,
                refusal,
                text: L(
                    "resize.max_size_reached",
                    "Maximum window size reached"
                )
            )
        )
    }

    /// Cues a float grow refused because BOTH edges are against
    /// the region it may occupy — the screen less its bars
    /// (#1091). The float path's third wall, and the one that
    /// had no cue at all until this: a blocked grow simply did
    /// nothing, which reads as a broken shortcut rather than a
    /// limit.
    ///
    /// Takes `.ownMaximum` rather than a case of its own, and
    /// that is a RULING rather than an observation: every
    /// consumer of the reason enum today — the ring's
    /// rubber-band, the mark — acts on "the resized window hit
    /// its own ceiling" and would do the same thing for either
    /// wall, so a second case would be a distinction nothing
    /// reads. The pill carries the difference because it is the
    /// only channel that can: a learned app maximum and a screen
    /// edge are one gesture stopped by different walls, and only
    /// the words tell them apart. A consumer that ever needs to
    /// ACT on which wall it was owes the case then — and owes it
    /// as structure, since #96 bars deciding that from the
    /// sentence.
    func refuseGrowAtBoundary(_ window: WindowID, axis: String) {
        let refusal = ResizeRefusal.ownMaximum(window)
        cueResizeRefusal(refusal)
        let direction: Direction = axis == "y" ? .down : .right
        flashDeadEnd(window, direction: direction)
        soundIfDrawn(
            flashSizeLimitPill(
                window,
                refusal,
                text: L(
                    "resize.boundary_reached",
                    "No room left to grow"
                )
            )
        )
    }

    /// Cues a resize refused because a NEIGHBOR sits at its own
    /// effective minimum (#933): the bump stays on the resized
    /// window (the gesture hit a wall), and BOTH ends pill with
    /// the text that fits its anchor — the resized window
    /// explains why nothing moved ("Neighboring window at its
    /// minimum size"), the blocking window marks itself
    /// ("Minimum window size reached"). One pill on the blocker
    /// alone read absurd there — from its own perspective IT
    /// reached the minimum, not a neighbor — and one on the
    /// trier alone leaves which window blocks unnamed (owner
    /// ruling, 2026-08-22; the #435 anchor rule still holds:
    /// the window that cannot move is marked).
    func refuseGrowAtNeighborMinimum(
        _ focused: WindowID,
        anchor: WindowID,
        axis: String
    ) {
        let refusal = ResizeRefusal.neighborMinimum(
            anchor: anchor,
            focused: focused
        )
        cueResizeRefusal(refusal)
        let direction: Direction = axis == "y" ? .down : .right
        flashDeadEnd(focused, direction: direction)
        soundIfDrawn(
            flashSizeLimitPill(
                focused,
                refusal,
                text: L(
                    "resize.neighbor_min_size",
                    "Neighboring window at its minimum size"
                )
            )
        )
        // The blocker's pill draws but does NOT sound: this is
        // one refusal wearing two pills, and one press that
        // beeps twice reads as two failures (#1255). It carries
        // the SAME glyph, which is the one refusal being worn
        // twice rather than two different ones (#1260).
        flashSizeLimitPill(
            anchor,
            refusal,
            text: L(
                "resize.min_size_reached",
                "Minimum window size reached"
            )
        )
    }
}
