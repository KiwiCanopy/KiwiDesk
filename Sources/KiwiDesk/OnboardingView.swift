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
        case readyToExplore
    }

    var step: Step = .welcome
    var isTrusted = false
    /// The closing card's "open at login" checkbox (#342).
    /// Pre-checked: the app's off-state after a reboot is a desktop
    /// of unmanaged windows, not a neutral absence, so the good
    /// default is on — one uncheck (here or in Settings) opts out.
    var openAtLogin = true
    /// Registers/unregisters the login item to match `openAtLogin`.
    /// Wired to `LoginItemManager`; a no-op stub keeps the model
    /// testable without touching `SMAppService`.
    var onSetLoginItem: (Bool) -> Void = { _ in }
    var onOpenSettings: () -> Void = {}
    /// Opens System Settings › Desktop & Dock (#8).
    var onOpenSpaceSettings: () -> Void = {}
    var onFinish: () -> Void = {}
    /// Closes onboarding and opens the dashboard on Layout — the
    /// "Open Settings" action of the discovery card (#331).
    var onExploreSettings: () -> Void = {}
    /// Whether the one-time post-setup discovery card should be
    /// shown now (false once its persisted flag is set). Gated on
    /// that flag, NEVER AX trust (#331).
    var wantsDiscovery: () -> Bool = { false }
    /// Live count of connected displays, so the recommendation
    /// fires only in the multi-display state that can actually
    /// suffer ambiguous Desktop→profile bindings (#8).
    var displayCount: () -> Int = { 1 }

    /// Shared display Spaces match KiwiDesk's one-active-profile
    /// model. Separate Spaces remain usable for basic tiling, so
    /// this is a recommendation the user may skip. `recommend`
    /// already folds in the display-count gate (a single display
    /// is never ambiguous), matching the Canvas section's shape.
    func continueAfterAccessibility(recommendSharedSpaces recommend: Bool) {
        if recommend {
            step = .separateSpaces
        } else {
            finishOrDiscover()
        }
    }

    /// The shared completion point every grant path converges on
    /// (grant-only and grant+Spaces): show the one-time discovery
    /// card if it's still pending, else just close (#331).
    ///
    /// The login-item choice lives on the discovery card, so a run
    /// that skips it (the card already shown) never had the chance
    /// to opt in — that is intended: the checkbox is a one-time
    /// offer, and Settings ▸ General carries the durable toggle for
    /// everyone after (#342).
    func finishOrDiscover() {
        if wantsDiscovery() {
            step = .readyToExplore
        } else {
            onFinish()
        }
    }

    /// Applies the closing card's "open at login" choice, then runs
    /// the chosen exit. Both exit buttons (Open Settings / Not Now)
    /// funnel through here so the checkbox is honored whichever the
    /// user picks (#342).
    func commitLoginItemThen(_ exit: () -> Void) {
        onSetLoginItem(openAtLogin)
        exit()
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
            case .readyToExplore:
                readyToExplore
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

    /// Recommend shared display Spaces only when separate Spaces
    /// are on *and* more than one display is connected — the
    /// gate the Canvas section already applies (#8).
    private func advancePastAccessibility() {
        model.continueAfterAccessibility(
            recommendSharedSpaces:
                DisplaySpacesSetting.recommendsSharedSpaces(
                    displayCount: model.displayCount()
                )
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
                model.finishOrDiscover()
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

    /// The one-time closing card (#331): points a fresh user at
    /// Settings and teaches that the app lives in the menu bar.
    /// "Not Now" is a real equal-weight exit — no forced visit,
    /// no repeat. Both routes hand off to the menu-bar popover.
    private var readyToExplore: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text(L("onboarding.ready.title", "You're ready to go"))
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text(readyToExploreBody)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            Toggle(
                L(
                    "onboarding.ready.open_at_login",
                    "Open KiwiDesk when I log in"
                ),
                isOn: $model.openAtLogin
            )
            .toggleStyle(.checkbox)
            Button(
                L("onboarding.ready.open_settings", "Open Settings")
            ) {
                model.commitLoginItemThen { model.onExploreSettings() }
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
            Button(L("onboarding.ready.not_now", "Not Now")) {
                model.commitLoginItemThen { model.onFinish() }
            }
        }
    }

    private var readyToExploreBody: String {
        L(
            "onboarding.ready.body",
            """
            KiwiDesk is already arranging your windows with \
            sensible defaults. Open Settings and apply a \
            preset for your setup — then fine-tune anything \
            from there. You can always get back here from the \
            menu bar — or press ⌃⌥K for a shortcuts \
            cheat-sheet.
            """
        )
    }
}
