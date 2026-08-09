import KiwiDeskCore

/// The inline sentence each `GapsBordersGates.InertReason`
/// renders — the "why you can't edit this" a greyed row or block
/// shows on hover. Split from the resolver so the resolver stays
/// assertable off the main actor; the reason and its sentence are
/// one decision, never two that can disagree (#678, gui.md).
///
/// A sentence is authored once, here, and never beside a row —
/// `GapsAndBordersGateWiringTests` reds on a second copy. When a
/// sentence's MEANING moves, its key is dropped in the same
/// change set (localization.md) rather than left to render a
/// fluent translation of what the row no longer does.
@MainActor
enum GapsBordersGateHelp {
    static func sentence(
        for reason: GapsBordersGates.InertReason
    ) -> String {
        switch reason {
        case .borderOff:
            return L(
                "border.controls.disabled",
                "Turn on Show focus border to edit "
                    + "these settings."
            )
        case .glowOff:
            return L(
                "border.glow_size.disabled",
                "Turn on Glow effect to adjust its size."
            )
        case .visualOff:
            return L(
                "drag.disabled.help",
                "Turn on Enabled to edit this visual."
            )
        case .visualBorderOff:
            return L(
                "drag.border.off_help",
                "Turn on Border to edit its width."
            )
        case .widthLinked:
            return L(
                "border.link_width.disabled",
                "Turn off Use one width for all borders to "
                    + "set this separately."
            )
        case .gapsDiffer:
            return L(
                "gaps.mixed.help",
                "Edges differ — edit them "
                    + "individually below."
            )
        }
    }
}
