import KiwiDeskCore
import SwiftUI

/// A Space's own gaps (#1775): one override for the whole `Gaps`
/// value, prefilled from the global gaps when checked, edited by
/// the Outer and Inner masters Gaps & Borders draws. Per-edge
/// values stay Lua's (`set_gap_override`) and read "mixed".
struct OverrideGapsRow: View {
    @Binding var value: Gaps?
    let global: Gaps

    var body: some View {
        OverrideChrome(
            isOn: overrideToggle($value, global: global),
            inherited: (Self.label, Self.summary(global)),
            inheritsFrom: .gapsAndBorders
        ) {
            VStack(alignment: .leading, spacing: 6) {
                GapsMasterRow(
                    label: L("gaps.outer", "Outer gap"),
                    value: current.outer.top,
                    mixed: GapsBordersGates.outerDiffers(current),
                    set: { v in
                        update {
                            $0.outer = Gaps.Outer(
                                top: v,
                                bottom: v,
                                left: v,
                                right: v
                            )
                        }
                    }
                )
                GapsMasterRow(
                    label: L("gaps.inner", "Inner gap"),
                    value: current.inner.horizontal,
                    mixed: GapsBordersGates.innerDiffers(current),
                    set: { v in
                        update {
                            $0.inner = Gaps.Inner(horizontal: v, vertical: v)
                        }
                    }
                )
            }
        }
    }

    static var label: String { L("gaps.title", "Gaps") }

    private var current: Gaps { value ?? global }

    private func update(_ change: (inout Gaps) -> Void) {
        var gaps = current
        change(&gaps)
        value = gaps
    }

    /// The inheriting row's value: both masters' readouts.
    static func summary(_ gaps: Gaps) -> String {
        L(
            "space_override.gaps.value",
            "outer %1$@, inner %2$@",
            GapsMasterRow.readout(
                gaps.outer.top,
                mixed: GapsBordersGates.outerDiffers(gaps)
            ),
            GapsMasterRow.readout(
                gaps.inner.horizontal,
                mixed: GapsBordersGates.innerDiffers(gaps)
            )
        )
    }
}
