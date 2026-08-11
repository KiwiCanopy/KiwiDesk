import KiwiDeskCore
import SwiftUI

extension OnboardingView {
    /// The multi-display Spaces recommendation (#8), unchanged in
    /// substance and moved to the end of the substantive steps
    /// (#678 Phase 4 pass 11) — it is a recommendation the user
    /// may skip, and it appears only when it can actually bite.
    var separateSpaces: some View {
        VStack(spacing: 14) {
            Image(systemName: "rectangle.split.2x1")
                .font(.system(size: 40))
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
                model.continueAfterSeparateSpaces()
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
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

    /// The closing card.
    ///
    /// **"Start using it" takes the default action**, and Open
    /// Settings is secondary (#678 Phase 4 pass 11). Return used
    /// to land on Open Settings, which said the opposite of this
    /// app's own ruling that Settings is for people who want to
    /// dig deeper rather than a prerequisite for using the thing.
    var done: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
            Text(L("onboarding.ready.title", "You're ready to go"))
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text(doneBody)
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
            Button(L("onboarding.ready.start", "Start using it")) {
                model.commitLoginItemThen { model.onFinish() }
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
            Button(
                L("onboarding.ready.open_settings", "Open Settings")
            ) {
                model.commitLoginItemThen { model.onExploreSettings() }
            }
        }
    }

    /// The old body told the user to "apply a preset for your
    /// setup", which became false the moment first run started
    /// seeding one: the Starter setup is already applied and
    /// already chosen for their screens. It says where the app
    /// lives instead — in words, which survive an auto-hidden
    /// menu bar where a picture of one does not.
    private var doneBody: String {
        L(
            "onboarding.ready.body",
            """
            KiwiDesk is managing your windows now, with a setup \
            chosen for your screens.

            It lives in the menu bar — click the kiwi for \
            Settings and help. If this is your first tiling \
            manager, you do not need Settings today.
            """
        )
    }
}
