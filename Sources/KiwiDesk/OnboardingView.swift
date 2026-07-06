import KiwiDeskCore
import SwiftUI

/// View state for the first-launch permission wizard.
@MainActor
@Observable
final class OnboardingModel {
    enum Step {
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
}

/// First-launch wizard guiding the user through granting
/// Accessibility permission.
struct OnboardingView: View {
    @Bindable var model: OnboardingModel

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
            Text("Welcome to KiwiDesk")
                .font(.largeTitle.bold())
            Text(
                """
                KiwiDesk arranges your windows automatically. \
                To move and resize windows of other apps, macOS \
                requires you to grant Accessibility permission.

                KiwiDesk never reads your keystrokes and does \
                not require disabling System Integrity \
                Protection.
                """
            )
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            Spacer()
            Button("Continue") {
                model.step = .grant
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
        }
    }

    private var grant: some View {
        VStack(spacing: 16) {
            statusIcon
            Text("Enable Accessibility")
                .font(.title.bold())
            Text(
                """
                1. Click “Open System Settings” below.
                2. Find KiwiDesk in the list and turn it on.
                3. Come back here — we detect it automatically.
                """
            )
            .foregroundStyle(.secondary)
            Spacer()
            if model.isTrusted {
                Text("Permission granted!")
                    .foregroundStyle(.green)
                Button("Continue") {
                    advancePastAccessibility()
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
            } else {
                Button("Open System Settings") {
                    model.onOpenSettings()
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
                Text("Waiting for permission…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
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

    /// After Accessibility, guide the display/Space model — but
    /// skip straight to finish when it's already enabled.
    private func advancePastAccessibility() {
        if DisplaySpacesSetting.hasSeparateSpaces() {
            model.onFinish()
        } else {
            model.step = .separateSpaces
        }
    }

    private var separateSpaces: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.split.2x1")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("Displays have separate Spaces")
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text(
                """
                KiwiDesk maps virtual spaces to specific \
                monitors. For that, macOS needs “Displays have \
                separate Spaces” turned on.

                Enable it in System Settings › Desktop & Dock, \
                then log out and back in. You can also skip this \
                and set it up later.
                """
            )
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            Spacer()
            Button("Open Desktop & Dock Settings") {
                model.onOpenSpaceSettings()
            }
            .controlSize(.large)
            Button("Continue") {
                model.onFinish()
            }
            .keyboardShortcut(.defaultAction)
        }
    }
}
