import KiwiDeskCore

/// Help explanations for disabled Gaps & Borders controls
/// (`GapsAndBordersGateWiringTests`, #678).
@MainActor
enum GapsBordersGateHelp {
    static func sentence(
        for reason: GapsBordersGates.InertReason
    ) -> String {
        switch reason {
        case .borderOff:
            return L(
                "border.controls.disabled",
                "Turn on %1$@ to edit these settings.",
                L("border.enabled", "Show focus border")
            )
        case .glowOff:
            return L(
                "border.glow_size.disabled",
                "Turn on %1$@ to adjust its size.",
                L("border.glow", "Glow effect")
            )
        case .visualOff:
            return L(
                "drag.disabled.help",
                "Turn on %1$@ to edit this visual.",
                L("drag.enabled", "Enabled")
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
