import KiwiDeskCore
import SwiftUI

/// A Space's own gaps (#1775): one override for the whole `Gaps`
/// value, prefilled from the global gaps when checked, edited by
/// an Outer and an Inner master. Per-edge values stay Lua's
/// (`set_gap_override`); edges set apart there read "mixed" and
/// the first drag converges them, as on Gaps & Borders (#1383).
struct OverrideGapsRow: View {
    @Binding var value: Gaps?
    let global: Gaps

    var body: some View {
        OverrideChrome(
            isOn: overrideToggle($value, global: global),
            inherited: (Self.label, Self.summary(global)),
            inheritsFrom: SettingsDestination.gapsAndBorders.title
        ) {
            VStack(alignment: .leading, spacing: 6) {
                masterRow(
                    label: L("gaps.outer", "Outer gap"),
                    reading: Self.outerReading(current),
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
                masterRow(
                    label: L("gaps.inner", "Inner gap"),
                    reading: Self.innerReading(current),
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

    /// A master's value, and whether the edges it sets differ.
    @MainActor
    struct Reading: Equatable {
        let value: CGFloat
        let mixed: Bool

        var text: String {
            mixed ? L("gaps.mixed", "mixed") : "\(Int(value)) pt"
        }
    }

    static func outerReading(_ gaps: Gaps) -> Reading {
        let o = gaps.outer
        return Reading(
            value: o.top,
            mixed: Set([o.top, o.bottom, o.left, o.right]).count > 1
        )
    }

    static func innerReading(_ gaps: Gaps) -> Reading {
        let i = gaps.inner
        return Reading(value: i.horizontal, mixed: i.horizontal != i.vertical)
    }

    /// The inheriting row's value: both masters' readouts.
    static func summary(_ gaps: Gaps) -> String {
        L(
            "space_override.gaps.value",
            "outer %1$@, inner %2$@",
            outerReading(gaps).text,
            innerReading(gaps).text
        )
    }

    private func masterRow(
        label: String,
        reading: Reading,
        set: @escaping (CGFloat) -> Void
    ) -> some View {
        SettingsRowShape {
            SettingsRowLabel(
                label: label,
                help: reading.mixed ? GapsBordersGateHelp.edgesDiffer : nil
            )
        } control: {
            HStack {
                SettingsSlider(
                    value: Binding(
                        get: { Double(reading.value) },
                        set: { set(CGFloat($0)) }
                    ),
                    range: 0...100,
                    step: 1,
                    label: label,
                    spokenValue: reading.text
                )
                Text(reading.text)
                    .settingsReadout()
                    .frame(
                        width: SettingsMetrics.readoutColumn,
                        alignment: .trailing
                    )
                    .foregroundStyle(.secondary)
                    .font(.body.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
    }
}
