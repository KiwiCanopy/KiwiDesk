import AppKit
import KiwiDeskCore
import SwiftUI

/// The first-launch permission wizard's window lifecycle and the
/// post-setup discovery beat (#331). Split from the main
/// `AppDelegate` file to keep both under the §2.1 size target; the
/// members it touches are `internal` there for the same reason.
extension AppDelegate {
    /// The QUICK MENU's "fix Accessibility" route: reopen the
    /// tour at its grant step, which explains what the permission
    /// is for and waits for it.
    ///
    /// The Settings banner deliberately does NOT come through
    /// here any more (#678 Phase 4 pass 9) — it opens the macOS
    /// pane directly, having already said what is wrong to a
    /// reader who is sitting in Settings. `AppDelegate`'s
    /// `setResolvePermission` wiring carries that argument.
    /// Changing this function therefore changes ONE surface.
    func showAccessibilityHelp() {
        onboardingModel.step = .grant
        showOnboarding()
    }

    /// Shows a profile's file in the Finder — the ONE
    /// implementation, handed to both surfaces that offer it: the
    /// Config Issues panel row and the broken-profile row under
    /// App ▸ Profiles (#246).
    ///
    /// Silent when the path won't validate. The name came from a
    /// directory listing that already rejected invalid ones, so a
    /// failure here means the file went away between the listing
    /// and the click — and the next refresh drops the row anyway.
    func revealProfile(_ name: String) {
        guard let url = try? core.profiles.fileURL(name: name)
        else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// The tour's one VOLUNTARY entry point — Home's "Show me
    /// around" (turn 14c). Starts at the top, where the
    /// involuntary callers land on the step their trigger needs —
    /// with the top being whichever screen still has something to
    /// say (`replayEntryStep`).
    func replayOnboardingTour() {
        onboardingModel.step = OnboardingEntry.replayStep(
            isTrusted: permissions.isTrusted
        )
        showOnboarding()
    }

    func showOnboarding() {
        if let window = onboardingWindow {
            NSApp.forceFront(window)
            return
        }
        onboardingModel.isTrusted = permissions.isTrusted
        onboardingModel.onOpenSettings = {
            PermissionMonitor.openSystemSettings()
        }
        onboardingModel.onOpenSpaceSettings = {
            DisplaySpacesSetting.openSystemSettings()
        }
        onboardingModel.displayCount = { [weak self] in
            self?.core.state.workspaces.allDisplays.count ?? 1
        }
        onboardingModel.onFinish = { [weak self] in
            self?.closeOnboarding()
        }
        // The closing card's "open at login" checkbox registers the
        // app as a login item via SMAppService (#342).
        onboardingModel.onSetLoginItem = { enabled in
            LoginItemManager.setEnabled(enabled)
        }
        // The shortcuts discovery page fires once, gated on its
        // own persisted flag — never AX trust, so a later TCC
        // reset never re-pitches (#331).
        onboardingModel.wantsDiscovery = {
            !OnboardingDiscovery.hasShown()
        }
        onboardingModel.onExploreSettings = { [weak self] in
            self?.openSettingsFromOnboarding()
        }
        // The spaces step draws the setup that was actually
        // seeded, from live state — never a description of it.
        onboardingModel.starterSpaces = { [weak self] in
            self?.starterSpaceCards() ?? []
        }
        onboardingModel.tilingSettings = { [weak self] in
            self?.core.tiler.settings ?? TilingSettings()
        }
        onboardingModel.screenNames = { [weak self] in
            self?.core.state.workspaces.allDisplays.map(\.name)
                ?? []
        }
        onboardingModel.keyFamilies = { [weak self] in
            self?.onboardingKeyFamilies() ?? []
        }

        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.title = L(
            "onboarding.window.title",
            "KiwiDesk Setup"
        )
        let host = NSHostingView(
            rootView: LocaleScopedRoot {
                OnboardingView(model: onboardingModel)
            }
            .environmentObject(LocalizationManager.shared)
        )
        window.contentView = host
        window.isReleasedWhenClosed = false
        window.delegate = self
        // Size BEFORE centering. `center()` on a still-zero-sized
        // window puts its bottom-left corner at the screen centre;
        // the SwiftUI frame then grows the window upward from
        // there, so the wizard opened tucked under the menu bar
        // instead of centred. Read the size from the view rather
        // than repeating `OnboardingView`'s own frame here — two
        // copies would drift the moment a step needs more room.
        window.setContentSize(host.fittingSize)
        window.center()
        // Stays `.normal` until Accessibility is granted — see
        // `floatOnboardingAboveManagedWindows()`. Floating it now
        // would park it over the System Settings window the grant
        // step sends the user to (#331).
        onboardingWindow = window

        // No promotion to `.regular` — `forceFront` shows and
        // activates the window from `.accessory` on its own, which
        // is the whole reason it exists.
        NSApp.forceFront(window)
    }

    /// Raise the still-open wizard above the windows tiling is
    /// about to move. Called on the grant transition, not at
    /// creation: before Accessibility is granted no tiling runs,
    /// so a `.normal` wizard can't be buried — and floating it
    /// early would cover the System Settings window the grant
    /// step opens (#331).
    func floatOnboardingAboveManagedWindows() {
        onboardingWindow?.level = .floating
    }

    func closeOnboarding() {
        // Closing routes through `windowWillClose`, which does the
        // teardown (and covers the red-button close, which the
        // "finish" button used to bypass).
        onboardingWindow?.close()
    }

    /// The closing card's "Open Settings": open the dashboard on
    /// Layout (its schematic preview is the most persuasive first
    /// impression) *before* closing onboarding.
    ///
    /// The order used to be about the activation policy — keeping
    /// a content window on screen so the close could not demote
    /// the app. That reason is gone with the promotion, and the
    /// order stays for the one below it: onboarding may be at
    /// `.floating` (`floatOnboardingAboveManagedWindows`), so
    /// showing Settings second would put it *under* a window that
    /// is about to disappear, and the user would watch the
    /// dashboard surface after the wizard vanished rather than
    /// behind it.
    func openSettingsFromOnboarding() {
        dashboard.show(navigatingTo: .layoutDefaults)
        closeOnboarding()
    }

    /// The discovery panel's Edit bridge must not leave the
    /// floating onboarding window above the requested Settings
    /// destination. Show Settings first, then close onboarding —
    /// the floating level is the whole reason, and it outlived
    /// the activation-policy argument that used to sit beside it.
    func openShortcutsSettings() {
        dashboard.show(navigatingTo: .shortcuts)
        if onboardingWindow != nil {
            closeOnboarding()
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard
            let closing = notification.object as? NSWindow,
            closing === onboardingWindow
        else { return }
        onboardingWindow = nil
        // Keyed on the MODEL's own "did this tour reach its end",
        // never on a list of terminal step cases (#678 Phase 4
        // pass 11). The case list was a second copy of the flow's
        // shape, and reordering the steps would have silently
        // killed both effects below with every test still green.
        if onboardingModel.reachedEnd {
            OnboardingDiscovery.markShown()
            // Home's 14c banner goes pending — the next Settings
            // visit opens oriented, not empty (turn 14c).
            HomeFirstRunState.seed(.standard)
            showMenuBarCoachMark()
        }
    }

    /// Points the one-time coach mark at the real menu-bar item.
    /// Skips itself when it cannot be honest — see
    /// `MenuBarCoachMark`, which owns both conditions.
    private func showMenuBarCoachMark() {
        coachMark.show(under: statusItem?.anchorButton)
    }

    /// The live default layer's chord families, for the keys step.
    private func onboardingKeyFamilies() -> [OnboardingKeyFamily] {
        guard
            let layer = core.loadGuiConfig().layers.first(
                where: { $0.isDefault }
            )
        else { return [] }
        return OnboardingKeys.families(
            layer: layer,
            spaces: SpaceID.deduplicated(
                core.state.workspaces.allSpaces.map(\.id)
            )
        )
    }

    /// The seeded spaces as the tour draws them, from LIVE state
    /// rather than from `StarterSetup` re-derived here: a replay
    /// after the user has renamed a space or changed a layout
    /// must show what they have, not what they were given.
    private func starterSpaceCards() -> [OnboardingSpaceCard] {
        let workspaces = core.state.workspaces
        return workspaces.allSpaces.map { space in
            OnboardingSpaceCard(
                id: space.id.raw,
                mode: space.mode,
                screen: workspaces.display(of: space.id)
                    .flatMap { id in
                        workspaces.allDisplays.first {
                            $0.id == id
                        }?.name
                    }
            )
        }
    }
}
