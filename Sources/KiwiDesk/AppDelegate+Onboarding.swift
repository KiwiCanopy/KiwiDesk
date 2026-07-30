import AppKit
import KiwiDeskCore
import SwiftUI

/// The first-launch permission wizard's window lifecycle and the
/// post-setup discovery beat (#331). Split from the main
/// `AppDelegate` file to keep both under the §2.1 size target; the
/// members it touches are `internal` there for the same reason.
extension AppDelegate {
    /// The shared "fix Accessibility" entry point for both the
    /// quick-menu warning row and the Settings banner: reopen the
    /// onboarding wizard straight at its grant step (skipping the
    /// welcome copy) so both routes land in the one explainer.
    func showAccessibilityHelp() {
        onboardingModel.step = .grant
        showOnboarding()
    }

    func showOnboarding() {
        if let window = onboardingWindow {
            // No `activateAsRegular()` here (unlike Settings' reuse
            // branch): `windowWillClose` nils `onboardingWindow` on
            // close, so a non-nil window is guaranteed still
            // `.regular` and the promotion never needs repeating.
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
        onboardingModel.onShowShortcuts = { [weak self] in
            self?.shortcutsPanel?.toggle()
        }
        onboardingModel.shortcutGlyphs = { [weak self] in
            guard let core = self?.core else { return "⌃⌥K" }
            return ShortcutsOpenBinding.comboGlyphs(core: core) ?? "⌃⌥K"
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

        NSApp.activateAsRegular()
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
        // Closing routes through `windowWillClose`, which does
        // the demote + teardown (also covers the red-button
        // close, which the "finish" button used to bypass).
        onboardingWindow?.close()
    }

    /// The closing card's "Open Settings": open the dashboard on
    /// Layout (its schematic preview is the most persuasive first
    /// impression) *before* closing onboarding, so the still-open
    /// dashboard keeps the app `.regular` and the close doesn't
    /// demote it.
    func openSettingsFromOnboarding() {
        dashboard.show(navigatingTo: .layoutDefaults)
        closeOnboarding()
    }

    /// The discovery panel's Edit bridge must not leave the
    /// floating onboarding window above the requested Settings
    /// destination. Show Settings first, then close onboarding so
    /// the app stays regular throughout the handoff.
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
        if onboardingModel.step == .discoverShortcuts
            || onboardingModel.step == .readyToExplore
        {
            OnboardingDiscovery.markShown()
        }
        NSApp.deactivateIfNoWindows(excluding: closing)
    }
}
