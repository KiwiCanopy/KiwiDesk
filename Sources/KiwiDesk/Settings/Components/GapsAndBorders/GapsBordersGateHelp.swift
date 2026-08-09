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
        case .gapsDiffer:
            return L(
                "gaps.mixed.help",
                "Edges differ — edit them "
                    + "individually below."
            )
        }
    }

    /// The shared masters' acknowledgement — not an
    /// `InertReason`, because those two rows stay live: with no
    /// per-stroke row anywhere on the page, greying them would
    /// name a disagreement and withhold the fix. It is a `?`
    /// beside a working control, so it says what a pick will do
    /// rather than what is stopping one.
    static var strokesDiffer: String {
        L(
            "border.shared.differ.help",
            "The three strokes are set differently right now; "
                + "choosing here sets all three."
        )
    }
}
