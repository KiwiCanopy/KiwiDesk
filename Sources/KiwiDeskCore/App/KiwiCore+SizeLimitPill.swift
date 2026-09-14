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
        // The frame the window was ISSUED (#934): a floor's
        // residue sits inward of its slot, and the pill draws on
        // the window.
        guard
            let frame = tiler.placedFrames(state: state)[window]
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

    /// **The one entry every resize refusal takes** (#1258),
    /// and `private` on purpose: that makes the builders below
    /// provably the entry set, rather than leaving two doors
    /// open for the next author to add a ninth builder AND a
    /// direct call.
    /// Every `refuse*` function below builds a case and hands it
    /// here; none of them draws, bumps or sounds itself, because
    /// a per-function body is where a wrong sentence and a
    /// missing bump hid through five review rounds.
    ///
    /// A PRESS cue also ends a held keyboard run (#1056), so a
    /// refusal pills once per hold rather than per frame —
    /// `HoldGlideEligibilitySeamTests` pins this as the only
    /// production caller of `borders.onResizeRefusal`, which is
    /// what makes "a cue stops the run" structural rather than a
    /// line to remember.
    ///
    /// `fromPress` is false for the one refusal a RETILE draws
    /// (#934, the split heal's unfit floor): the pills and the
    /// border report, without the glide note (no hold to end)
    /// or the bump (no trier); the sound keeps its own gate,
    /// which already requires a press in flight.
    private func cueResizeRefusal(
        _ refusal: ResizeRefusal,
        fromPress: Bool = true
    ) {
        if fromPress {
            keys.noteResizeRefusal()
        }
        borders.onResizeRefusal(refusal)
        if let direction = refusal.bumpDirection {
            if fromPress {
                flashDeadEnd(refusal.window, direction: direction)
            }
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

    /// The layout has no resizing at all (#1255): monocle and
    /// grid. A correct no-op — macOS's own full-screen exposes
    /// no resize either — but a perceivable one, and it is the
    /// MOST reachable refusal in the feature, not the least: any
    /// resize press in either arrives here. It cued by sound
    /// alone until #1255.
    ///
    /// An empty space cues nothing: every refusal is drawn ON a
    /// window, so with no focus there is nothing to draw and
    /// nothing to sound beside it.
    func refuseResizeUnsupported(in space: Space) {
        guard let window = space.focused else { return }
        cueResizeRefusal(.layoutHasNoResize(window))
    }

    /// The focused window is in native full screen (#1298).
    func refuseWindowIsFullscreen(_ window: WindowID) {
        cueResizeRefusal(.windowIsFullscreen(window))
    }

    /// A shrink hit the window's effective minimum (#933) — on
    /// the FIRST attempt the clamp truncates, landing ON the
    /// minimum included, not only once already there. Which
    /// term of that minimum bound is derived HERE, once for
    /// every path (#1261, `minimumIsAppBound`).
    func refuseShrinkAtMinimum(_ window: WindowID, axis: String) {
        cueResizeRefusal(
            .ownMinimum(
                window,
                axis: axis,
                appBound: minimumIsAppBound(of: window, axis: axis)
            )
        )
    }

    /// A grow refused at the window's own learned app-enforced
    /// maximum (#1055) — `refuseShrinkAtMinimum`'s mirror at the
    /// other end. One pill only: the limit is the resized
    /// window's own app, so there is no second window to mark —
    /// and the sentence says so (#1261), needing no
    /// discriminator since no configured maximum exists.
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
    /// renderer's (`ResizeRefusal.secondPill`); whose floor the
    /// anchor sits at is derived here from the anchor (#1261).
    func refuseGrowAtNeighborMinimum(
        _ focused: WindowID,
        anchor: WindowID,
        axis: String
    ) {
        cueResizeRefusal(
            .neighborMinimum(
                anchor: anchor,
                focused: focused,
                axis: axis,
                appBound: minimumIsAppBound(of: anchor, axis: axis)
            )
        )
    }

    /// The split heal's unfit floor (#934): `overhanging` cannot
    /// be made room for because `anchor` already sits at its own
    /// floor — the neighbour-minimum pair, drawn by a retile
    /// rather than a press.
    func refuseFloorUnfitAtRetile(
        _ overhanging: WindowID,
        anchor: WindowID,
        axis: String
    ) {
        cueResizeRefusal(
            .neighborMinimum(
                anchor: anchor,
                focused: overhanging,
                axis: axis,
                appBound: minimumIsAppBound(of: anchor, axis: axis)
            ),
            fromPress: false
        )
    }
}
