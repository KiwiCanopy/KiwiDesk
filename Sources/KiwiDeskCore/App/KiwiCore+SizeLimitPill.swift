import AppKit
import CoreGraphics

extension KiwiCore {
    /// Flashes one refusal pill (#933). The glyph and the text
    /// both come from the refusal's own case (#1260/#1258), so
    /// the two channels cannot disagree and neither can be
    /// chosen at a call site.
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

    /// **The one entry every resize refusal takes** (#1258).
    /// Every `refuse*` function below builds a case and hands it
    /// here; none of them draws, bumps or sounds itself, because
    /// a per-function body is where a wrong sentence and a
    /// missing bump hid through five review rounds.
    ///
    /// It also ends a held keyboard run (#1056), so a refusal
    /// pills once per hold rather than per frame —
    /// `HoldGlideEligibilitySeamTests` pins this as the only
    /// production caller of `borders.onResizeRefusal`, which is
    /// what makes "a cue stops the run" structural rather than a
    /// line to remember.
    func cueResizeRefusal(_ refusal: ResizeRefusal) {
        keys.noteResizeRefusal()
        borders.onResizeRefusal(refusal)
        if refusal.bumps, let axis = refusal.axis {
            flashDeadEnd(
                refusal.window,
                direction: axis == "y" ? .down : .right
            )
        }
        soundIfDrawn(
            flashSizeLimitPill(
                refusal.window,
                refusal,
                text: refusal.pillText
            )
        )
        // One refusal, two ends — and the second never sounds.
        if let second = refusal.secondPill {
            flashSizeLimitPill(
                second.window,
                refusal,
                text: second.text
            )
        }
    }

    /// The zone has no parameter on the asked axis (#1255).
    func refuseAxisAbsent(_ window: WindowID, axis: String) {
        cueResizeRefusal(.noAxisHere(window, axis: axis))
    }

    /// The group this axis divides has one member (#1258);
    /// `otherAxisDivides` is the caller's reading of its own
    /// partition, and rides the case so a test can see it.
    func refuseNothingToDivide(
        _ window: WindowID,
        otherAxisDivides: Bool
    ) {
        cueResizeRefusal(
            .nothingToDivide(
                window,
                otherAxisDivides: otherAxisDivides
            )
        )
    }

    /// The layout has no resizing at all (#1255): monocle, grid
    /// and floating. A correct no-op — macOS's own full-screen
    /// exposes no resize either — but a perceivable one, and it
    /// is the MOST reachable refusal in the feature, not the
    /// least: any resize press in one of those three arrives
    /// here. It cued by sound alone until #1255.
    ///
    /// An empty space cues nothing: every refusal is drawn ON a
    /// window, so with no focus there is nothing to draw and
    /// nothing to sound beside it.
    func refuseResizeUnsupported(in space: Space) {
        guard let window = space.focused else { return }
        cueResizeRefusal(.layoutHasNoResize(window))
    }

    /// A shrink hit the window's effective minimum (#933) — on
    /// the FIRST attempt the clamp truncates, landing ON the
    /// minimum included, not only once already there.
    func refuseShrinkAtMinimum(_ window: WindowID, axis: String) {
        cueResizeRefusal(.ownMinimum(window, axis: axis))
    }

    /// A grow refused at the window's own learned app-enforced
    /// maximum (#1055) — `refuseShrinkAtMinimum`'s mirror at the
    /// other end. One pill only: the limit is the resized
    /// window's own app, so there is no second window to mark.
    func refuseGrowAtMaximum(_ window: WindowID, axis: String) {
        cueResizeRefusal(
            .ownMaximum(window, axis: axis, atBoundary: false)
        )
    }

    /// A float grow refused because BOTH edges are against the
    /// region it may occupy — the screen less its bars (#1091).
    ///
    /// Shares `.ownMaximum` rather than taking a case of its
    /// own, and that is a RULING: every consumer of the reason
    /// acts on "the resized window hit its own ceiling" and
    /// would do the same for either wall. Only the WORDS tell a
    /// learned app maximum from a screen edge apart, which is
    /// why the distinction rides the case as a flag the renderer
    /// reads rather than as a second case — observable at the
    /// seam either way (#1258), where before #1258 it was
    /// observable at neither.
    func refuseGrowAtBoundary(_ window: WindowID, axis: String) {
        cueResizeRefusal(
            .ownMaximum(window, axis: axis, atBoundary: true)
        )
    }

    /// A resize refused because a NEIGHBOR sits at its own
    /// effective minimum (#933). The pairing — which window
    /// wears the second pill, and what it says — is the
    /// renderer's (`ResizeRefusal.secondPill`).
    func refuseGrowAtNeighborMinimum(
        _ focused: WindowID,
        anchor: WindowID,
        axis: String
    ) {
        cueResizeRefusal(
            .neighborMinimum(
                anchor: anchor,
                focused: focused,
                axis: axis
            )
        )
    }
}
