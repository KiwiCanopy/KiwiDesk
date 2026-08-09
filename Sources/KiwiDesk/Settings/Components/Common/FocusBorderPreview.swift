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

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.12))
            HStack(spacing: 16) {
                window(
                    color: style.focusedColor,
                    ringed: true,
                    // Glow is focused-ring-only (#358).
                    glow: style.glow
                )
                window(
                    color: style.unfocusedColor,
                    ringed: style.unfocusedEnabled,
                    glow: false
                )
            }
            .padding(14)
        }
        .frame(height: 96)
        .frame(maxWidth: .infinity)
        .opacity(style.enabled ? 1 : 0.4)
    }

    private func window(
        color: String,
        ringed: Bool,
        glow: Bool
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
