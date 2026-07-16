import KiwiDeskCore
import SwiftUI

/// View state for the first-launch permission wizard.
@MainActor
@Observable
final class OnboardingModel {
    enum Step: Equatable {
        case welcome
        case grant
        case separateSpaces
    }

    var step: Step = .welcome
    var isTrusted = false
    var onOpenSettings: () -> Void = {}
    /// Opens System Settings › Desktop & Dock (#8).
    var onOpenSpaceSettings: () -> Void = {}
    var onFinish: () -> Void = {}

    /// Shared display Spaces match KiwiDesk's one-active-profile
    /// model. Separate Spaces remain usable for basic tiling, so
    /// this is a recommendation the user may skip.
    func continueAfterAccessibility(
        hasSeparateSpaces: Bool
    ) {
        if hasSeparateSpaces {
            step = .separateSpaces
        } else {
            onFinish()
        }
    }
}

/// First-launch wizard guiding the user through granting
/// Accessibility permission.
struct OnboardingView: View {
    @Bindable var model: OnboardingModel
    @EnvironmentObject private var localization: LocalizationManager

    var body: some View {
        VStack(spacing: 24) {
            switch model.step {
            case .welcome:
                welcome
            case .grant:
                grant
            case .separateSpaces:
                separateSpaces
            }
        }
        .padding(32)
        .frame(width: 480, height: 360)
    }

    private var welcome: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text(L("onboarding.welcome.title", "Welcome to KiwiDesk"))
                .font(.largeTitle.bold())
            Text(welcomeBody)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            Button(L("onboarding.continue", "Continue")) {
                model.step = .grant
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
        }
    }

    private var welcomeBody: String {
        L(
            "onboarding.welcome.body",
            """
            KiwiDesk arranges your windows automatically. \
            To move and resize windows of other apps, macOS \
            requires you to grant Accessibility permission.

            KiwiDesk never reads your keystrokes and does \
            not require disabling System Integrity \
            Protection.
            """
        )
    }

    private var grant: some View {
        VStack(spacing: 16) {
            statusIcon
            Text(
                L(
                    "onboarding.grant.title",
                    "Enable Accessibility"
                )
            )
            .font(.title.bold())
            Text(grantBody)
                .foregroundStyle(.secondary)
            Spacer()
            if model.isTrusted {
                Text(
                    L(
                        "onboarding.grant.granted",
                        "Permission granted!"
                    )
                )
                .foregroundStyle(.green)
                Button(L("onboarding.continue", "Continue")) {
                    advancePastAccessibility()
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
            } else {
                Button(
                    L(
                        "onboarding.grant.open_settings",
                        "Open System Settings"
                    )
                ) {
                    model.onOpenSettings()
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
                Text(
                    L(
                        "onboarding.grant.waiting",
                        "Waiting for permission…"
                    )
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var grantBody: String {
        L(
            "onboarding.grant.body",
            """
            1. Click “Open System Settings” below.
            2. Find KiwiDesk in the list and turn it on.
            3. Come back here — we detect it automatically.
            """
        )
    }

    private var statusIcon: some View {
        Image(
            systemName: model.isTrusted
                ? "checkmark.circle.fill"
                : "lock.shield"
        )
        .font(.system(size: 56))
        .foregroundStyle(model.isTrusted ? .green : .orange)
        .animation(.spring, value: model.isTrusted)
    }

    /// Recommend shared display Spaces only when the separate
    /// display model is currently enabled.
    private func advancePastAccessibility() {
        model.continueAfterAccessibility(
            hasSeparateSpaces:
                DisplaySpacesSetting.hasSeparateSpaces()
        )
    }

    private var separateSpaces: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.split.2x1")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text(
                L(
                    "onboarding.spaces.title",
                    "Use shared Spaces across displays"
                )
            )
            .font(.title.bold())
            .multilineTextAlignment(.center)
            Text(separateSpacesBody)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            Button(
                L(
                    "onboarding.spaces.open_settings",
                    "Open Desktop & Dock Settings"
                )
            ) {
                model.onOpenSpaceSettings()
            }
            .controlSize(.large)
            Button(L("onboarding.continue", "Continue")) {
                model.onFinish()
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    private var separateSpacesBody: String {
        L(
            "onboarding.spaces.body",
            """
            KiwiDesk uses one active profile across all \
            displays. For predictable Desktop-to-profile \
            bindings, turn off “Displays have separate Spaces.”

            Basic tiling still works if you keep it on. Changing \
            this setting requires logging out and back in.
            """
        )
    }
}
