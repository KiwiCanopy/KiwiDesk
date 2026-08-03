import KiwiDeskCore

/// The inline sentence each `GapsBordersGates.InertReason`
/// renders — the "why you can't edit this" a greyed row or block
/// shows on hover. Split from the resolver so the resolver stays
/// assertable off the main actor; the reason and its sentence are
/// one decision, never two that can disagree (#678, gui.md).
///
/// Every key here is reused from the hand-wired gate this
/// conversion replaced, so the English is unchanged and no
/// translation is dropped.
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
                "Turn on Border to edit its width and "
                    + "alignment."
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
