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

    /// The tour's one VOLUNTARY entry point — Home's "Show me
    /// around" (turn 14c). Resets to the welcome step so a
    /// replay starts at the top, where the involuntary callers
    /// land on the step their trigger needs.
    func replayOnboardingTour() {
        onboardingModel.step = .welcome
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
        if onboardingModel.step == .discoverShortcuts
            || onboardingModel.step == .readyToExplore
        {
            OnboardingDiscovery.markShown()
            // The tour reached its closing beats, so Home's
            // 14c banner goes pending — the next Settings
            // visit opens oriented, not empty (turn 14c).
            HomeFirstRunState.seed()
        }
    }
}
