import AppKit
import CoreGraphics

extension KiwiCore {
    /// Flashes one refusal pill (#933). Every caller hands it
    /// the glyph and the text of ONE renderer — a resize
    /// refusal's case (#1260/#1258) or a Tile refusal's reason
    /// (#1810) — never a literal of its own.
    @discardableResult
    private func flashSizeLimitPill(
        _ window: WindowID,
        symbol: String,
        text: String
    ) -> Bool {
        flashRefusalPill(
            window,
            text: text,
            symbol: symbol,
            announce: false
        )
    }

    /// The frame a refusal pill draws on: the one the window was
    /// ISSUED (#934) — a floor's residue sits inward of its slot.
    func refusalPillFrame(_ window: WindowID) -> CGRect? {
        tiler.placedFrames(state: state)[window]
            ?? state.windows[window]?.frame
    }

    /// The one door every refusal pill takes, the resize family's
    /// and the window actions' (#1518) alike. `announce` is each
    /// caller's to state: a pill VoiceOver must hear speaks through
    /// `announceRefusal` (#2480).
    @discardableResult
    func flashRefusalPill(
        _ window: WindowID,
        text: String,
        symbol: String,
        announce: Bool,
        spoken: String? = nil
    ) -> Bool {
        if announce { borders.announceRefusal(spoken ?? text) }
        guard let frame = refusalPillFrame(window) else { return false }
        return borders.flashSizeLimitPill(
            window: window,
            frame: frame,
            text: text,
            symbol: symbol
        )
    }

    /// The audible half of a refusal (#1255): a drawn pill may
    /// also sound, which is what the toggle has always claimed
    /// to control and now does.
    ///
    /// The hotkey-fire gate is inherited deliberately (#184): a
    /// resize driven from the CLI or IPC must not make the
    /// user's Mac beep at a script. And a glide step never reaches
    /// this, so a chord sounds for its press alone — which is what
    /// makes sounding a real refusal safe where sounding every
    /// `.fail` never was.
    func soundRefusal() {
        // A pressed write's report stands in for its fire (#2994).
        guard keys.isFiring || tiler.applier.fixedSizeDoor.reportingPress
        else { return }
        soundPanelRefusal()
    }

    /// The refusal sound for a refusal a panel drew itself — KiwiHub
    /// keeps a refused pick open with its reason in the row (#2885)
    /// — so no hotkey fire gates it: the press is the panel's own.
    public func soundPanelRefusal() {
        guard appWide.refusalSound else { return }
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
    /// called from the `refuse*` builders in
    /// `KiwiCore+ResizeRefusals.swift` alone, which makes them
    /// provably the entry set (`RefusalCueSeamTests`).
    /// Every `refuse*` function there builds a case and hands it
    /// here; none of them draws, bumps or sounds itself, because
    /// a per-function body is where a wrong sentence and a
    /// missing bump hid through five review rounds.
    ///
    /// A PRESS cue also ends a held keyboard run (#1056), and a
    /// glide step's refusal ends it with no cue at all (#3017) —
    /// `HoldGlideEligibilitySeamTests` pins this as the only
    /// production caller of `borders.onResizeRefusal`, which is
    /// what makes "a refusal stops the run" structural rather than a
    /// line to remember.
    ///
    /// `fromPress` is false for the one refusal a RETILE draws
    /// (#934, the split heal's unfit floor): the pills and the
    /// border report, without the glide note (no hold to end)
    /// or the bump (no trier); the sound keeps its own gate,
    /// which already requires a press in flight.
    func cueResizeRefusal(
        _ refusal: ResizeRefusal,
        fromPress: Bool = true
    ) {
        // A hold stops silently at any limit; a press cues (#3017).
        let pressed =
            keys.isFiring || tiler.applier.fixedSizeDoor.reportingPress
        let silent = fromPress && keys.holdGlide.isGliding && !pressed
        if fromPress {
            keys.noteResizeRefusal()
        }
        if silent { return }
        borders.onResizeRefusal(refusal)
        if let direction = refusal.bumpDirection {
            if fromPress {
                flashDeadEnd(refusal.window, direction: direction)
            }
        }
        soundIfDrawn(
            flashSizeLimitPill(
                refusal.window,
                symbol: refusal.pillSymbol,
                text: refusal.pillText
            )
        )
        // One refusal, two ends — and the second never sounds.
        if let second = refusal.secondPill {
            flashSizeLimitPill(
                second.window,
                symbol: refusal.pillSymbol,
                text: second.text
            )
        }
    }

    /// A Tile refused because detection floats the window
    /// (#1810): the pill names the refused act and the reason,
    /// the sentence the bar menu's greyed row carries too.
    func cueTileRefusal(_ window: WindowID, _ reason: AutoFloatReason) {
        borders.onTileRefusal(window, reason)
        soundIfDrawn(
            flashSizeLimitPill(
                window,
                symbol: reason.pillSymbol,
                text: reason.pillSentence
            )
        )
    }
}
