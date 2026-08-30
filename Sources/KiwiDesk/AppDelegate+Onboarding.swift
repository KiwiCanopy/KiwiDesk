import AppKit
import KiwiDeskCore
import SwiftUI

/// The first-launch permission wizard's window lifecycle and the
/// post-setup discovery beat (#331). Split from the main
/// `AppDelegate` file to keep both under the §2.1 size target; the
/// members it touches are `internal` there for the same reason.
extension AppDelegate {
    /// Reopens the onboarding tour at the grant step (#678).
    func showAccessibilityHelp() {
        showOnboarding(at: .grant)
    }

    /// Shows a profile's file in the Finder (#246).
    func revealProfile(_ name: String) {
        guard let url = try? core.profiles.fileURL(name: name)
        else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Replays the onboarding tour from the highest step with
    /// unacknowledged content (`replayEntryStep`).
    func replayOnboardingTour() {
        showOnboarding(
            at: OnboardingEntry.replayStep(
                isTrusted: permissions.isTrusted
            )
        )
    }

    /// Opens the tour at the specified `entry` step (#828).
    func showOnboarding(at entry: OnboardingModel.Step) {
        if let window = onboardingWindow {
            // A reopen navigates to the requested step and raises.
            onboardingModel.beginPresentation(at: entry)
            NSApp.forceFront(window)
            return
        }
        onboardingModel.isTrusted = permissions.isTrusted
        // Seeded from current boot phase to prevent premature .ready (#802).
        onboardingModel.bootPhase = core.bootPhase
        onboardingModel.onOpenSettings = {
            PermissionMonitor.openSystemSettings()
        }
        onboardingModel.onFinish = { [weak self] in
            self?.closeOnboarding()
        }
        // Registers login item via SMAppService (#342).
        onboardingModel.onSetLoginItem = { enabled in
            LoginItemManager.setEnabled(enabled)
        }
        onboardingModel.starterSpaces = { [weak self] in
            self?.starterSpaceCards() ?? []
        }
        onboardingModel.tilingSettings = { [weak self] in
            self?.core.tiler.settings ?? TilingSettings()
        }
        onboardingModel.keyFamilies = { [weak self] in
            self?.onboardingKeyFamilies() ?? []
        }
        // Resolved after wiring so step handlers are in place (#828, #888).
        onboardingModel.beginPresentation(at: entry)

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
        // Cleared so SwiftUI page ground is the one copy of window ground.
        window.backgroundColor = .clear
        window.isOpaque = false
        // Sized before centering so center() calculates from final bounds.
        window.setContentSize(host.fittingSize)
        window.center()
        // Stays .normal until Accessibility is granted (#331).
        onboardingWindow = window

        // forceFront shows and activates from .accessory without promotion.
        NSApp.forceFront(window)
    }

    /// Raises the wizard above managed windows on permission grant (#331).
    func floatOnboardingAboveManagedWindows() {
        onboardingWindow?.level = BarPanel.aboveLevel
    }

    func closeOnboarding() {
        // Teardown is handled in `windowWillClose`.
        onboardingWindow?.close()
    }

    /// Opens Settings to shortcuts and closes onboarding to avoid
    /// leaving a floating window above Settings.
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
        // Keyed on model completion rather than hardcoded step cases (#678).
        if onboardingModel.reachedEnd {
            OnboardingDiscovery.markShown()
            HomeFirstRunState.seed(.standard)
        }
        // Reset flag so subsequent presentations do not re-trigger completion.
        onboardingModel.clearReachedEnd()
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

    /// Returns current space cards from live state.
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
