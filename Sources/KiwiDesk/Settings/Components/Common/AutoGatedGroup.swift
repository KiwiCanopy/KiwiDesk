import KiwiDeskCore
import SwiftUI

/// A toggle that gates the control(s) directly below it. One
/// `VStack` binds the switch above what it owns, so flipping it on
/// reads as "this switch controls what's under it" — the
/// Apple-native grouping (AGENTS §2.7). On greys the manual
/// control(s) via the #171 "grey, don't hide" treatment
/// (`GreyOut`): they stay visible but disabled and dimmed, never
/// removed.
///
/// Shared by the App Bar Auto item/font-size pairs (the toggle is
/// the `0 = auto` sentinel exposed through `AppBarAuto.binding`)
/// and the Grid Auto-size block (a plain `autoSize` bool gating
/// the Columns/Rows steppers). Before this component those three
/// spelled the same interaction three ways, with different visual
/// binding strengths, purely by which feature wave wrote them
/// (#233).
struct AutoGatedGroup<Gated: View>: View {
    let title: String
    @Binding var isOn: Bool
    /// Optional one-line caption naming where the automatic value
    /// comes from when the gated control can't show it itself
    /// (Grid: the screen plus the minimum window size). Omitted
    /// where the gated slider already teaches its own automatic
    /// behaviour (the App Bar sizes), keeping the caption's job to
    /// "name a source the control can't" rather than gloss "why".
    var caption: String? = nil
    @ViewBuilder let gated: Gated

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(title, isOn: $isOn)
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            gated
                .modifier(GreyOut(active: isOn))
        }
    }
}

/// The #171 "grey, don't hide" treatment: a control that has no
/// effect in the current mode stays visible but disabled and
/// dimmed, with an optional explanatory tooltip. Generic (not
/// App-Bar-specific) — `AutoGatedGroup`, the App Bar roundness
/// gate, and the per-layout override all share it.
struct GreyOut: ViewModifier {
    let active: Bool
    var help: String = ""

    func body(content: Content) -> some View {
        content
            .disabled(active)
            .opacity(active ? 0.5 : 1)
            .help(active ? help : "")
    }
}
