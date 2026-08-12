import KiwiDeskCore
import SwiftUI

/// The tour's progress row (#828): one pip per screen THIS
/// presentation will show, the current one widened.
///
/// **What pass 11 banned and this is not.** That ruling killed a
/// FIXED counter — "step 3 of 5" asserted on a machine that shows
/// three screens, two of the five being conditional. The list here
/// is `OnboardingModel.plannedSteps`, resolved from the same
/// answers the transitions take, so the row is true on every path;
/// `OnboardingProgressTests` proves it by walking the model's own
/// transitions rather than by re-listing the steps. A row drawn
/// from anything else — `Step.allCases`, a constant, a count that
/// ignores the entry door — is the banned counter wearing this
/// name, and the repair is to delete the row, not to patch it.
///
/// **Two channels, never hue alone.** Done and current pips take
/// the accent, upcoming ones `hairline`; the current pip is told
/// from the done ones by WIDTH. So the row survives both colour
/// vision deficiency and the appearance flip, and it coins no
/// third token.
struct OnboardingProgressRow: View {
    let steps: [OnboardingModel.Step]
    let index: Int

    /// A pip's height, and an upcoming pip's width — page dots at
    /// the size AppKit draws them, not a control the user can aim
    /// at. The row is decoration with a value: nothing here is
    /// hittable, because a pip that looks clickable promises a
    /// navigation this flow does not offer.
    private let pip: CGFloat = 6
    private let currentPip: CGFloat = 20

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(steps.enumerated()), id: \.offset) {
                position,
                _ in
                Capsule()
                    .fill(
                        position <= index
                            ? SettingsTheme.accent
                            : SettingsTheme.hairline
                    )
                    .frame(
                        width: position == index
                            ? currentPip : pip,
                        height: pip
                    )
            }
        }
        .animation(.default, value: index)
        // One element with a value, never N unlabelled pips: read
        // apart they are five decorations with no number in them,
        // and the number is the whole content.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            L("onboarding.progress.axlabel", "Setup progress")
        )
        // Both numbers sit at the END of the frame, and neither is
        // followed by a noun that would have to agree with it —
        // the shape `.claude/rules/localization.md` requires of a
        // frame carrying a count, satisfied here with two.
        .accessibilityValue(
            L(
                "onboarding.progress.axvalue",
                "Screen %1$d of %2$d",
                index + 1,
                steps.count
            )
        )
    }
}
