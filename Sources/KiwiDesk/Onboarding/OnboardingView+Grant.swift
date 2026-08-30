import KiwiDeskCore
import SwiftUI

/// Tour screen for Accessibility permission setup (#678, #828).
extension OnboardingView {
    /// Initial tour screen requesting Accessibility permissions (#828).
    var grant: some View {
        OnboardingPage(
            title: grantTitle,
            body1: grantBody,
            hint: grantHintForPhase,
            hintPulses: isArranging
        ) {
            wordmark
            if model.isTrusted {
                grantedMark
            } else {
                grantSteps
            }
        } action: {
            if model.isTrusted {
                Button(L("onboarding.continue", "Continue")) {
                    model.continueAfterAccessibility()
                }
                .kiwiProminentButton()
                .keyboardShortcut(.defaultAction)
            } else {
                Button(
                    L(
                        "common.open_system_settings",
                        "Open System Settings"
                    )
                ) {
                    model.onOpenSettings()
                }
                .kiwiProminentButton()
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    /// Title string for current grant state (OnboardingGrantPhaseTests, #801).
    var grantTitle: String {
        guard model.isTrusted else {
            return L(
                "onboarding.grant.title",
                "KiwiDesk needs Accessibility"
            )
        }
        return model.bootPhase == .ready
            ? L(
                "onboarding.grant.done.title",
                "Your windows are arranged"
            )
            : L(
                "onboarding.grant.arranging.title",
                "Arranging your windows"
            )
    }

    var grantBody: String {
        guard model.isTrusted else { return grantLead }
        guard model.bootPhase != .ready else { return grantedBody }
        return [
            L(
                "onboarding.grant.arranging.body",
                """
                KiwiDesk is going through your open apps and \
                putting their windows in place. On a busy Mac \
                this takes a moment.
                """
            ),
            ownWindowNote,
        ].joined(separator: "\n\n")
    }

    /// Whether window arrangement scan is actively running (#801).
    var isArranging: Bool {
        model.isTrusted && grantHintCount != nil
    }

    var grantHintForPhase: String? {
        guard model.isTrusted else { return grantHint }
        guard let count = grantHintCount else { return nil }
        return L(
            "onboarding.grant.arranging.count",
            "Going through your open apps: %1$d of %2$d",
            count.scanned,
            count.total
        )
    }

    private var grantHintCount: (scanned: Int, total: Int)? {
        guard
            case .scanning(let scanned, let total) =
                model.bootPhase
        else { return nil }
        return (scanned, total)
    }

    private var ownWindowNote: String {
        L(
            "onboarding.grant.own_window",
            "Windows like this one are never tiled, because they "
                + "go away."
        )
    }

    private var wordmark: some View {
        Group {
            if let image = brandWordmark {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180)
            } else {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 40))
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityLabel(L("brand.menu_bar_icon.a11y", "KiwiDesk"))
    }

    private var brandWordmark: NSImage? {
        colorScheme == .dark
            ? (BrandAssets.wordmarkDark ?? BrandAssets.wordmark)
            : BrandAssets.wordmark
    }

    /// Steps card explaining how to grant Accessibility permissions.
    private var grantSteps: some View {
        VStack(alignment: .leading, spacing: 10) {
            grantStep(
                1,
                L(
                    "onboarding.grant.step.open",
                    "Open Privacy & Security ▸ Accessibility"
                )
            )
            grantStep(
                2,
                L(
                    "onboarding.grant.step.enable",
                    "Switch KiwiDesk on"
                )
            )
            waitingLine
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
        }
        .onboardingCard()
    }

    /// Centered confirmation shown once Accessibility is granted (#828).
    private var grantedMark: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 38))
                .foregroundStyle(SettingsTheme.accent)
            Text(
                L("onboarding.grant.granted", "Permission granted")
            )
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(SettingsTheme.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 18)
        .accessibilityElement(children: .combine)
    }

    private func grantStep(
        _ number: Int,
        _ text: String
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 12))
                .foregroundStyle(SettingsTheme.groupHeading)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(SettingsTheme.sunken)
                )
            Text(text)
                .font(.system(size: 13.5))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    /// Status line while waiting for system permission grant (#828).
    private var waitingLine: some View {
        HStack(spacing: 9) {
            WaitingDot()
            Text(
                L(
                    "onboarding.grant.waiting",
                    "Waiting — this page continues by itself"
                )
            )
            .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 12.5))
        .foregroundStyle(SettingsTheme.ink3)
        .accessibilityElement(children: .combine)
    }

    /// Privacy and SIP reassurance note shown in the footer.
    private var grantHint: String {
        L(
            "onboarding.grant.trust",
            "KiwiDesk never reads your keystrokes, and never "
                + "asks you to disable System Integrity "
                + "Protection."
        )
    }

    private var grantLead: String {
        L(
            "onboarding.grant.lead",
            "macOS only lets an app move windows once you allow "
                + "it. Nothing here works until this is on."
        )
    }

    /// Explanation of arranged windows shown once granted (#678, #818).
    private var grantedBody: String {
        [
            L(
                "onboarding.grant.done.body",
                "Take a look behind this window — your open "
                    + "windows have been arranged."
            ),
            ownWindowNote,
        ].joined(separator: "\n\n")
    }
}
