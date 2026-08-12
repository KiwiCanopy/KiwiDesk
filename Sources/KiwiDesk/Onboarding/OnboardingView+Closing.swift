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
                .foregroundStyle(SettingsTheme.accent)
            Text(
                L(
                    "onboarding.spaces.title",
                    "Use shared Desktops across displays"
                )
            )
            .font(.title.bold())
            .multilineTextAlignment(.center)
            Text(separateSpacesBody)
                .multilineTextAlignment(.center)
                .foregroundStyle(SettingsTheme.ink2)
            Spacer()
            // Secondary rank through the seal, never a raw
            // `.bordered`: the tinted window paints a bordered
            // button's LABEL from the accent, which is #759 (#828
            // brought the tint here, so it brings the seal too).
            Button(
                L(
                    "onboarding.spaces.open_settings",
                    "Open Desktop & Dock Settings"
                )
            ) {
                model.onOpenSpaceSettings()
            }
            .settingsActionButton()
            .controlSize(.large)
            Button(L("onboarding.continue", "Continue")) {
                model.continueAfterSeparateSpaces()
            }
            .buttonStyle(.borderedProminent)
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
                .foregroundStyle(SettingsTheme.accent)
            Text(L("onboarding.ready.title", "You're ready to go"))
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text(doneBody)
                .multilineTextAlignment(.center)
                .foregroundStyle(SettingsTheme.ink2)
            Spacer()
            menuBarIdentity
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
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
            Button(
                L("onboarding.ready.open_settings", "Open Settings")
            ) {
                model.commitLoginItemThen { model.onExploreSettings() }
            }
            .settingsActionButton()
        }
    }

    /// Where the app lives, shown INSIDE the window (#828, owner
    /// ruled 2026-08-12).
    ///
    /// It replaces the desktop coach mark that used to float under
    /// the real menu-bar item after the tour closed: an overlay
    /// outside every KiwiDesk window is a surface the app cannot
    /// promise anything about — it pointed at a strip that a
    /// menu-bar manager may have moved, and it skipped itself
    /// entirely under an auto-hidden menu bar, which is precisely
    /// the user who most needs telling. Drawn here, the picture is
    /// on a surface the app owns and every user sees it.
    ///
    /// The mark is the REAL menu-bar image, template-flagged, so
    /// what the user matches against the menu bar is the same
    /// artwork rather than an SF Symbol standing in for it.
    private var menuBarIdentity: some View {
        HStack(spacing: 10) {
            Group {
                if let icon = BrandAssets.menuBarIcon {
                    Image(nsImage: icon)
                        .frame(width: 18, height: 18)
                } else {
                    Image(
                        systemName: "menubar.arrow.up.rectangle"
                    )
                }
            }
            .foregroundStyle(SettingsTheme.ink)
            Text(menuBarBody)
                .font(.callout)
                .foregroundStyle(SettingsTheme.ink2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(SettingsTheme.sunken)
        )
        // One element: the mark and the sentence are one fact, and
        // read apart the picture is an unnamed image.
        .accessibilityElement(children: .combine)
    }

    /// Deictic on purpose — "this" points at the mark drawn beside
    /// it, which is on this page. The retired coach mark's own
    /// sentence said "in here" about a menu bar the user had to
    /// find first.
    private var menuBarBody: String {
        L(
            "onboarding.ready.menu_bar",
            "Look for this in your menu bar. Settings and your "
                + "shortcuts are behind it."
        )
    }

    /// The old body told the user to "apply a preset for your
    /// setup", which became false the moment first run started
    /// seeding one: the Starter setup is already applied and
    /// already chosen for their screens.
    ///
    /// Where the app lives moved OUT of this paragraph and into
    /// `menuBarIdentity`, beside the mark it names (#828) — said
    /// in both places it was the same sentence twice, and the
    /// version with the picture is the one a user can match.
    private var doneBody: String {
        L(
            "onboarding.ready.body",
            """
            KiwiDesk is managing your windows now, with a setup \
            chosen for your screens.

            If this is your first tiling manager, you do not need \
            Settings today.
            """
        )
    }
}
