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
/// the `0 = auto` sentinel exposed through `AutoSentinel.binding`)
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
    /// Whether the gated controls are genuinely inert. Defaults
    /// to `isOn` — the common case, where this toggle is the only
    /// thing that can silence them. A surface whose value can be
    /// re-enabled elsewhere passes a narrower predicate: the
    /// global Grid editor's steppers stay live for any space that
    /// overrides auto-size OFF, and greying a control something
    /// still reads is the worse direction (#520, #527).
    var gatedIsInert: Bool? = nil
    /// The why-you-cannot sentence for the greyed controls. The
    /// toggle directly above them usually answers it by
    /// adjacency, which is why this is optional — but a caller
    /// whose gate is resolved from the census carries a reason
    /// with it, and without somewhere to put it that reason is
    /// authored, translated and never shown.
    var gatedHelp: String = ""
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
                .modifier(
                    GreyOut(
                        active: gatedIsInert ?? isOn,
                        help: gatedHelp
                    )
                )
        }
    }
}

/// The #171 "grey, don't hide" treatment: a control that has no
/// effect in the current mode stays visible but disabled and
/// dimmed. Generic (not App-Bar-specific) — `AutoGatedGroup`,
/// the App Bar roundness gate, and the per-layout override all
/// share it.
///
/// `help` is a HOVER fallback only (`.help()`), never the #94
/// affordance: `.disabled` is cumulative, so any `HelpButton`
/// inside the wrapped content is dead while the gate is active.
/// A *block* gate therefore renders its explanation as a live
/// `?` on an anchor outside the gated subtree — the
/// `SettingsSection` header (`help:`) or a disclosure label
/// (#527). A *control-scoped* gate (one row, its gating control
/// directly adjacent) keeps just this hover string: the
/// adjacency already answers "why", the way the toggle above an
/// `AutoGatedGroup` does.
///
/// **A "no tooltip" report is AppKit's tooltip delay until
/// proven otherwise** (2026-08-03): the greyed Columns/Rows
/// steppers under Grid's Auto-size toggle read as having no
/// hover string at all, and the cause was the default delay,
/// not the gate. `.disabled()` does NOT suppress `.help()`.
/// Hover long enough and the sentence appears.
///
/// That is worth a line here because the wrong reading is the
/// tempting one — the string is on a disabled control, so the
/// control looks like the culprit — and it sent one change down
/// a workaround that fixed nothing. Reach for the delay first.
///
/// **Dims once, however deeply it nests.** Opacity multiplies,
/// so a row inside an already-dimmed block used to land at
/// `0.25` and read as broken rather than disabled. The #520
/// sweep, which gates whole editors, made that reachable from
/// the shipping defaults — an Auto-gated slider inside a
/// switched-off bar hit it with one click.
///
/// The first active gate dims and publishes that fact; every
/// gate below it still `.disabled`s (correct — the control is
/// inert either way) but leaves opacity alone. Conjoining each
/// inner predicate by hand was the alternative and is one more
/// thing to forget; this makes the invariant unrepresentable
/// instead of merely documented.
///
/// **The reason a grey carries still does not reach the keyboard
/// path, and that is a KNOWN gap, not an oversight** (#678 Phase
/// 4 pass 10). A greyed row announces its name and "dimmed"; the
/// sentence explaining why lives in `.help()`, which needs a
/// pointer to read.
///
/// An `.accessibilityHint(active ? help : "")` beside the
/// `.help()` was written here and then BACKED OUT, because two
/// things about it could not be verified without a live
/// accessibility client and both failure modes are real:
///
/// - This modifier is applied at BLOCK granularity in several
///   places (`BarColorCards`, `AppBarCard`, `LayoutCard`), so
///   whether a hint on the wrapper reaches the controls inside
///   decides between "twelve gates announce nothing" and "every
///   control in a greyed card repeats one sentence".
/// - The empty string when inactive is on the path of every
///   descendant that sets a hint of its OWN — `ColorField`'s
///   swatches do, under exactly these block gates — so if an
///   ancestor's empty hint wins, the change silently deletes
///   hints that ship today.
///
/// A headless probe cannot answer either: SwiftUI builds its
/// accessibility children lazily and a hosted view reports only
/// its root group. So the mechanism needs an Accessibility
/// Inspector / VoiceOver session on a gated colour card first,
/// and the answer may well be that a grey's reason belongs
/// INLINE as text (the redesign's item 19 — "why-you-cannot
/// always inline, VoiceOver reads it" — which `LoginItemCard`
/// and `LoginItemCard` already do) rather than in a hint at all.
/// Tracked as its own issue; do not re-add the hint here without
/// that observation recorded.
struct GreyOut: ViewModifier {
    let active: Bool
    var help: String = ""
    @Environment(\.isInsideGreyOut) private var alreadyDimmed

    func body(content: Content) -> some View {
        content
            .disabled(active)
            .opacity(active && !alreadyDimmed ? 0.5 : 1)
            .help(active ? help : "")
            .environment(
                \.isInsideGreyOut,
                alreadyDimmed || active
            )
    }
}

private struct GreyOutDepthKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True once some ancestor has already applied the grey
    /// treatment, so a nested dim would compound it. Read by
    /// `GreyOut` and by `OverrideChrome`, which dims inheriting
    /// rows through the same mechanism.
    var isInsideGreyOut: Bool {
        get { self[GreyOutDepthKey.self] }
        set { self[GreyOutDepthKey.self] = newValue }
    }
}

/// The `0 = automatic` sentinel's GUI face: a Bool binding over
/// a numeric field where `0` means automatic, so the Auto
/// toggle reads and writes the sentinel without a second stored
/// flag. Turning auto OFF seeds `restore` — pass the value the
/// automatic behavior currently produces where it is computable
/// (the glow size), a sensible constant where it is not (the
/// bar sizes, whose auto values are content-measured at render).
/// Promoted from the Bars area (as `AppBarAuto`) when the Focus
/// border glow became its second client (#551) — `Common/`
/// admits primitives shared across component areas.
enum AutoSentinel {
    static func binding(
        _ value: Binding<CGFloat>,
        restore: CGFloat
    ) -> Binding<Bool> {
        Binding(
            get: { value.wrappedValue == 0 },
            set: { value.wrappedValue = $0 ? 0 : restore }
        )
    }
}
