import KiwiDeskCore
import SwiftUI

/// Shared by the Gaps & Borders editor (which owns the ring's
/// structure) and the Advanced Colours Borders group (which owns
/// its tints) — `Common/` admits a primitive once a second
/// component area needs it. The redesign rule is that a preview is
/// RECYCLED, never rebuilt from a mock, so the colour page leads
/// with this exact view rather than a scene of its own.
///
/// Two mock windows on a neutral desktop: the focused one always
/// ringed, the other ringed only when unfocused borders are on.
/// Reflects width and corner style live so the editor's controls
/// preview before they hit real windows.
struct FocusBorderPreview: View {
    let style: BorderStyle
    /// The sticky mark, drawn on the focused window when the
    /// area that owns the mark is the one previewing (owner,
    /// 2026-08-16). `nil` in a mount whose subject is only the
    /// ring — the parameter is what keeps this ONE renderer
    /// instead of a second window mock beside it.
    ///
    /// It belongs on this picture rather than on the gap
    /// diagram: the mark is an overlay on a WINDOW, and this is
    /// the only preview here that draws one. Gaps are about the
    /// space between windows and have nothing to hang it on.
    var sticky: StickyStyle? = nil

    var body: some View {
        picture
            // One element with one summary, never a tour of the
            // shapes (#678 Phase 4 pass 10, turn 20a rule 2):
            // it is a picture of the result, so tabbing through
            // its two windows would be tabbing through nothing
            // actionable. Every other preview in the tree already
            // reads aloud through text it happens to contain — a
            // legend, a caption, a chip — and this one is the pure
            // drawing that had nothing, so it announced nothing at
            // all.
            .accessibilityElement()
            .accessibilityLabel(axLabel)
    }

    /// Conditional on what is actually drawn, for the reason
    /// #708 made explicit: a spoken label may no more assert a
    /// mark the frame omits than a written caption may. The
    /// mark arm is reached only where a mount passes `sticky`
    /// AND the toggle is on. Both scopes are drawn together, so
    /// one sentence covers the pair.
    private var axLabel: String {
        stickyMark == nil
            ? L(
                // Names its subject, as the sibling preview keys
                // do (`app_bar.preview.ax`, `space_bar.preview.ax`):
                // in the VoiceOver rotor there is no visual
                // context, and a bare "Preview:" announces a
                // preview of nothing (l10n audit, 2026-08-11).
                "border.preview.ax",
                "Border preview: a focused window with its "
                    + "ring, beside an unfocused one."
            )
            : L(
                "border.preview.ax_sticky",
                "Border preview: a focused window with its ring "
                    + "and the everywhere-sticky mark, beside an "
                    + "unfocused one with the one-display mark."
            )
    }

    private var picture: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.12))
            HStack(spacing: 16) {
                window(
                    color: style.focusedColor,
                    ringed: true,
                    // Glow is focused-ring-only (#358).
                    glow: style.glow,
                    mark: stickyMark
                )
                window(
                    color: style.unfocusedColor,
                    ringed: style.unfocusedEnabled,
                    glow: false,
                    // The DISPLAY-sticky scope on the second
                    // window (owner, on device, 2026-08-16).
                    // One window showing one scope taught only
                    // half the family: `StickyStyle` draws two
                    // glyphs — `infinity` for a window on every
                    // Space of every monitor, `pin.fill` for one
                    // tacked to a single display (#445) — they
                    // share one tint, and the pair is the thing
                    // a reader needs to tell apart.
                    mark: displayStickyMark
                )
            }
            .padding(14)
        }
        .frame(height: 96)
        .frame(maxWidth: .infinity)
        .opacity(style.enabled ? 1 : 0.4)
    }

    /// The mark to draw, or nil. Gated on the style's own
    /// `mark` toggle, so turning the glyph off turns it off here
    /// — which is the whole point of showing it: the reader can
    /// see what the switch does before saving.
    /// Internal so `GapsBordersPanelTests` can read the
    /// decision: whether a mark is drawn is a BRANCH, and a
    /// branch that stops being written passes every source
    /// needle above it (the Monitors lesson, `gui.md`).
    var stickyMark: (symbol: String, tint: Color)? {
        mark(for: .global)
    }

    /// The display-sticky twin, drawn on the unfocused window so
    /// the two scopes sit side by side.
    var displayStickyMark: (symbol: String, tint: Color)? {
        mark(for: .display)
    }

    /// Both scopes read ONE toggle and ONE tint — that is the
    /// "one glyph everywhere" family (#414), and the preview
    /// would be lying if it let them diverge.
    private func mark(
        for scope: StickyScope
    ) -> (symbol: String, tint: Color)? {
        guard let sticky, sticky.mark,
            let symbol = StickyStyle.symbolName(for: scope)
        else { return nil }
        return (symbol, .kiwiMark(sticky.color))
    }

    private func window(
        color: String,
        ringed: Bool,
        glow: Bool,
        mark: (symbol: String, tint: Color)?
    ) -> some View {
        // Remap the 1–20 pt width onto the preview's smaller span
        // so a thick border reads without swamping the mock —
        // through the ONE remap the Home tile also reads
        // (`BorderPreviewScale`, #786 review).
        let width = BorderPreviewScale.width(
            style.clampedWidth,
            to: 1...7
        )
        // Remap the RESOLVED glow blur (auto formula or the
        // explicit glow_size, #533/#551) the same way — the
        // literal pt value would swamp this 96 pt mock and
        // read as a smear, not a halo (#358). A proportional
        // approximation, like width and corners here.
        // The source band is derived from the formula's own
        // clamp, so a retuned floor/cap cannot leave this remap
        // silently stale (the numbers live in
        // `BorderGeometryTests`, nowhere else); an explicit
        // size past the band clamps at the mock's top, which
        // is honest enough for a schematic.
        let glowRadius = scale(
            style.resolvedGlowBlur,
            from: BorderStyle.glowBlur(
                for: BorderStyle.minWidth
            )...BorderStyle.glowBlur(for: BorderStyle.maxWidth),
            to: 1...5
        )
        let radius: CGFloat =
            style.cornerStyle == .square ? 0 : 12
        return RoundedRectangle(cornerRadius: radius)
            .fill(Color.secondary.opacity(0.25))
            .overlay {
                if ringed {
                    // Preview the configured visible width. The real
                    // renderer adds a hidden overlap behind the
                    // window, which does not change this weight.
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(
                            Color(kiwiHex: color),
                            lineWidth: width
                        )
                        .shadow(
                            // Bloom uses the brightened derivative,
                            // matching the real renderer (#358).
                            color: glow
                                ? Color(
                                    kiwiHex: BorderStyle.glowColor(
                                        from: color
                                    )
                                )
                                : .clear,
                            radius: glow ? glowRadius : 0
                        )
                }
            }
            .overlay(alignment: .topTrailing) {
                if let mark {
                    Image(systemName: mark.symbol)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(mark.tint)
                        .padding(5)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func scale(
        _ value: CGFloat,
        from src: ClosedRange<CGFloat>,
        to dst: ClosedRange<CGFloat>
    ) -> CGFloat {
        let span = src.upperBound - src.lowerBound
        guard span > 0 else { return dst.lowerBound }
        let t = min(max((value - src.lowerBound) / span, 0), 1)
        return dst.lowerBound
            + t * (dst.upperBound - dst.lowerBound)
    }
}
