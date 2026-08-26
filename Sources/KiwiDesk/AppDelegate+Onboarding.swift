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
        showOnboarding(at: .grant)
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
        showOnboarding(
            at: OnboardingEntry.replayStep(
                isTrusted: permissions.isTrusted
            )
        )
    }

    /// Opens the tour on `entry`.
    ///
    /// The step is a PARAMETER rather than something a caller
    /// assigns first, because the progress row's length is
    /// resolved from it — and resolved after the closures below
    /// are wired, which a caller setting `model.step` itself
    /// cannot arrange (#828).
    func showOnboarding(at entry: OnboardingModel.Step) {
        if let window = onboardingWindow {
            // A REOPEN navigates, it does not merely raise. Every
            // caller used to assign `model.step` before this
            // early return, so the revoke path and the quick
            // menu's "fix Accessibility" both landed on the grant
            // screen even with the tour already up; taking the
            // step as a parameter silently dropped that until the
            // review caught it. Re-planning here is also what
            // keeps the row honest — the plan starts at the step
            // the presentation is now on.
            onboardingModel.beginPresentation(at: entry)
            NSApp.forceFront(window)
            return
        }
        onboardingModel.isTrusted = permissions.isTrusted
        // Seeded, not only pushed: a replay opened mid-boot would
        // otherwise inherit the model's `.ready` default and claim
        // a finished arrangement (#802).
        onboardingModel.bootPhase = core.bootPhase
        onboardingModel.onOpenSettings = {
            PermissionMonitor.openSystemSettings()
        }
        onboardingModel.onFinish = { [weak self] in
            self?.closeOnboarding()
        }
        // The closing card's "open at login" checkbox registers the
        // app as a login item via SMAppService (#342).
        onboardingModel.onSetLoginItem = { enabled in
            LoginItemManager.setEnabled(enabled)
        }
        // The spaces step draws the setup that was actually
        // seeded, from live state — never a description of it.
        onboardingModel.starterSpaces = { [weak self] in
            self?.starterSpaceCards() ?? []
        }
        onboardingModel.tilingSettings = { [weak self] in
            self?.core.tiler.settings ?? TilingSettings()
        }
        onboardingModel.keyFamilies = { [weak self] in
            self?.onboardingKeyFamilies() ?? []
        }
        // After the wiring: the plan is resolved once per
        // presentation (#828). Since #888 it reads no machine
        // seams — the route varies only by its door — but a
        // future machine-gated step would read them here, so the
        // ordering stays deliberate.
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
        // The window's OWN ground, not just the view's. With a
        // transparent titlebar over `.fullSizeContentView` the
        // system window colour shows through the title strip and
        // in every gap the hosting view has not painted, which is
        // the "still looks greyish" the tint pass left behind
        // (owner, on device, 2026-08-12). Cleared rather than
        // painted: the SwiftUI `page` behind the content is the
        // one copy of the ground, and an `NSColor` here would be
        // a second one to keep in step.
        window.backgroundColor = .clear
        window.isOpaque = false
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
    ///
    /// `BarPanel.aboveLevel`, derived from where the bars render
    /// rather than written as `.floating` + 1 here: as peers the
    /// two settle in raise order, so a bar could cover the window
    /// the user is being asked to read. The bars reserve their
    /// strip and the tour is centred, so on the reported setup
    /// they never actually met — the raise is what keeps that
    /// true on a setup where they would (owner confirmed the
    /// behaviour on device, 2026-08-12).
    func floatOnboardingAboveManagedWindows() {
        onboardingWindow?.level = BarPanel.aboveLevel
    }

    func closeOnboarding() {
        // Closing routes through `windowWillClose`, which does the
        // teardown (and covers the red-button close, which the
        // "finish" button used to bypass).
        onboardingWindow?.close()
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
        }
        // Consumed, so the flag means "THIS presentation reached
        // the end" and not "this model ever did". The model is a
        // stored `let` on the delegate and outlives every window,
        // so without this a later reopen at the grant step — the
        // quick menu's "fix Accessibility" route — would close
        // having fired both effects again. They are each
        // idempotent behind their own persisted flag today; the
        // third effect added inside that `if` would not be
        // (code review, 2026-08-11).
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
