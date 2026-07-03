import SwiftUI

/// View state for the first-launch permission wizard.
@MainActor
@Observable
final class OnboardingModel {
    enum Step {
        case welcome
        case grant
    }

    var step: Step = .welcome
    var isTrusted = false
    var onOpenSettings: () -> Void = {}
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
                Text("Permission granted — you're all set!")
                    .foregroundStyle(.green)
                Button("Start KiwiDesk") {
                    model.onFinish()
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
}
