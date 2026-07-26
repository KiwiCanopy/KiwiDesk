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
        // The post-setup discovery card fires once, gated on its
        // own persisted flag — never AX trust, so a later TCC
        // reset never re-pitches (#331).
        onboardingModel.wantsDiscovery = {
            !OnboardingDiscovery.hasShown()
        }
        onboardingModel.onExploreSettings = { [weak self] in
            self?.exploreFromDiscovery()
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
        window.contentView = NSHostingView(
            rootView: LocaleScopedRoot {
                OnboardingView(model: onboardingModel)
            }
            .environmentObject(LocalizationManager.shared)
        )
        window.isReleasedWhenClosed = false
        window.delegate = self
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

    /// The discovery card's "Open Settings": open the dashboard on
    /// Layout (its schematic preview is the most persuasive first
    /// impression) *before* closing onboarding, so the still-open
    /// dashboard keeps the app `.regular` and the close doesn't
    /// demote it. Suppresses the menu-bar hint for this route —
    /// the user is already being led into the app (#331).
    func exploreFromDiscovery() {
        openedSettingsFromDiscovery = true
        dashboard.show(navigatingTo: .layoutDefaults)
        closeOnboarding()
    }

    func windowWillClose(_ notification: Notification) {
        guard
            let closing = notification.object as? NSWindow,
            closing === onboardingWindow
        else { return }
        onboardingWindow = nil
        // Demote *before* the hint. On the Not Now / red-button
        // routes no other content window remains, so this flips the
        // app to `.accessory`; showing the `.transient` popover
        // first and demoting after risks the policy change
        // dismissing it. The still-visible closing window is
        // excluded from the count.
        NSApp.deactivateIfNoWindows(excluding: closing)
        fireDiscoveryHintIfPending()
    }

    /// The one-time discovery hint, fired from the single close
    /// funnel every exit route passes through. Burns the shared
    /// flag so it never repeats, then shows the menu-bar popover
    /// only on routes that did NOT open Settings — opening it
    /// already leads the user into the app, so the hint would just
    /// be a second surface at a far corner (#331, ui-designer B).
    private func fireDiscoveryHintIfPending() {
        guard onboardingModel.step == .readyToExplore else {
            return
        }
        OnboardingDiscovery.markShown()
        let suppressed = openedSettingsFromDiscovery
        openedSettingsFromDiscovery = false
        guard !suppressed else { return }
        statusItem?.showDiscoveryPopover()
    }
}
