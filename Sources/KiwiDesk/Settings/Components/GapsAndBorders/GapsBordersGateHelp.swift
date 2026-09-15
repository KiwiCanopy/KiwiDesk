import KiwiDeskCore

/// Help explanations for disabled Gaps & Borders controls: a
/// sentence is authored once, HERE, never beside a row —
/// `GapsAndBordersGateWiringTests` reds on a second copy (#678).
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
        }
    }

    /// The shared masters' acknowledgement — not an
    /// `InertReason`, because those two rows stay live: a `?`
    /// beside a working control says what a pick will do rather
    /// than what is stopping one.
    static var strokesDiffer: String {
        L(
            "border.shared.differ.help",
            "The three strokes are set differently right now; "
                + "choosing here sets all three."
        )
    }

    /// The gap masters' acknowledgement, the strokes' shape
    /// (#1383): the slider stays live over a "mixed" readout and
    /// the first drag converges every edge, the way an inspector
    /// treats a mixed selection.
    static var edgesDiffer: String {
        L(
            "gaps.master.differ.help",
            "The edges are set differently right now; "
                + "a value here sets all of them."
        )
    }
}
