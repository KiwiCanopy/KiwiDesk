import KiwiDeskCore
import SwiftUI

/// Toggle gating controls directly below it via `GreyOut` (#171, #233).
struct AutoGatedGroup<Gated: View>: View {
    let title: String
    @Binding var isOn: Bool
    /// Optional caption explaining automatic source when gated control cannot.
    var caption: String? = nil
    /// Whether gated controls are inert; defaults to `isOn` (#520, #527).
    var gatedIsInert: Bool? = nil
    /// Reason string explaining why controls are disabled.
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

/// Disables and dims inert controls without compounding opacity
/// (#171, #520): the first active gate dims and publishes the fact;
/// nested gates still `.disabled` but leave opacity alone.
///
/// `help` is a HOVER fallback only, never the #94 affordance:
/// `.disabled` is cumulative, so a `HelpButton` inside the gated
/// content is dead — a block gate anchors a live `?` outside the
/// subtree (#527). And a "no tooltip" report is AppKit's default
/// tooltip delay until proven otherwise — `.disabled()` does NOT
/// suppress `.help()` (2026-08-03).
///
/// Do not re-add an `.accessibilityHint` beside the `.help()`:
/// written and BACKED OUT pending a live VoiceOver observation of
/// block-granularity hints (#678 Phase 4 pass 10; tracked issue).
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
    /// True when ancestor already applied dimming, avoiding compounding
    /// opacity.
    var isInsideGreyOut: Bool {
        get { self[GreyOutDepthKey.self] }
        set { self[GreyOutDepthKey.self] = newValue }
    }
}

/// Binding adapter mapping numeric `0 = auto` sentinel to Bool toggle (#551).
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
