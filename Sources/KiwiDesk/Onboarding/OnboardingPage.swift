import KiwiDeskCore
import SwiftUI

/// Standard layout template for onboarding tour screens (#828).
struct OnboardingPage<Content: View, Action: View>: View {
    let title: String
    /// Primary body text tier.
    let body1: String
    /// Secondary text tier drawn when non-nil.
    var footnote: String?
    /// Whether the footnote renders below content instead of below the body.
    var footnoteAtBottom = false
    /// Bottom-left contextual hint supporting markdown bold (#1019).
    var hint: String?
    /// Whether a pulsing dot precedes the hint for in-flight tasks (#802).
    var hintPulses = false
    /// Emphasizes the hint tier when presenting a destination link (#1019).
    var hintLeads = false
    /// Embedded interactive link within the hint (#828).
    var hintLink: HintLink?

    struct HintLink {
        let label: String
        let action: () -> Void
    }
    @ViewBuilder var content: Content
    @ViewBuilder var action: Action

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(onboardingEmphasis(body1))
                    .font(.system(size: 14))
                    .foregroundStyle(SettingsTheme.ink2)
                    // Every copy tier wraps rather than truncates:
                    // a fixed window plus German is how the grant
                    // step shipped a clipped sentence (owner, on
                    // device, 2026-08-12).
                    .fixedSize(horizontal: false, vertical: true)
                if let footnote, !footnoteAtBottom {
                    footnoteText(footnote)
                }
            }
            content
            Spacer(minLength: 0)
            if let footnote, footnoteAtBottom {
                footnoteText(footnote)
            }
            HStack(alignment: .center, spacing: 10) {
                if let hint {
                    HStack(alignment: .center, spacing: 9) {
                        if hintPulses {
                            WaitingDot(ink: SettingsTheme.ink3)
                        }
                        hintView(hint)
                    }
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                } else {
                    Spacer(minLength: 0)
                }
                action
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
    }

    private func footnoteText(_ text: String) -> some View {
        Text(onboardingEmphasis(text))
            .font(.system(size: 12.5))
            .foregroundStyle(SettingsTheme.ink3)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Formats hint text, or builds a `LinkedCaption` when `hintLink` is set.
    @ViewBuilder
    private func hintView(_ text: String) -> some View {
        if let hintLink {
            let parts = LinkedCaption.split(frame: text)
            LinkedCaption(
                leading: parts.0,
                linkTitle: hintLink.label,
                trailing: parts.1,
                navigate: hintLink.action,
                pointSize: hintLeads ? 13 : 12.5,
                ink: NSColor(
                    hintLeads
                        ? SettingsTheme.ink2 : SettingsTheme.ink3
                )
            )
        } else {
            hintText(text)
        }
    }

    private func hintText(_ text: String) -> some View {
        Text(onboardingEmphasis(text))
            .font(.system(size: 12.5))
            .foregroundStyle(SettingsTheme.ink3)
            .fixedSize(horizontal: false, vertical: true)
    }

}

/// Parses inline markdown `**bold**` into `SettingsTheme.ink` foreground.
func onboardingEmphasis(_ text: String) -> AttributedString {
    guard
        var parsed = try? AttributedString(
            markdown: text,
            options: .init(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        )
    else { return AttributedString(text) }
    for run in parsed.runs
    where run.inlinePresentationIntent == .stronglyEmphasized {
        parsed[run.range].foregroundColor = SettingsTheme.ink
    }
    return parsed
}

/// Bordered card container modifier (12 pt radius, hairline stroke).
struct OnboardingCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(SettingsTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(SettingsTheme.hairline, lineWidth: 1)
            )
    }
}

extension View {
    func onboardingCard() -> some View {
        modifier(OnboardingCard())
    }
}
