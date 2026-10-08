import AppKit
import KiwiDeskCore

extension AppDelegate {
    /// The trail between What's new and Settings (#2038 ruling ▸
    /// handoff), wired once at bootstrap: the coordinator owns it,
    /// Settings draws it.
    func wireWhatsNewTrail() {
        guard let whatsNew = updater.whatsNew else { return }
        whatsNew.showsInSettings = { [weak self] trail in
            self?.dashboard.follow(trail)
        }
        whatsNew.endsTrail = { [weak self] in
            self?.dashboardIfCreated?.endWhatsNewTrail()
        }
    }

    /// "What's new" at launch (#1542, #1667): the window only for
    /// a launch the user started and no tour owns — the permission
    /// grant or a resuming discovery — otherwise the mark. A
    /// relaunch after the window's own Install is the exception:
    /// Sparkle starts it, so it opens whatever the origin, still
    /// never over the tour, and before boot so it narrates it.
    func offerWhatsNew(origin: LaunchOrigin, trusted: Bool) {
        guard let whatsNew = updater.whatsNew else { return }
        let tourOwns = OnboardingDiscovery.shouldResume(
            isTrusted: trusted
        )
        let opensWindow = origin == .user && trusted && !tourOwns
        let existingUser = OnboardingDiscovery.hasShown()
        let narrated = whatsNew.relaunched(
            opensWindow: trusted && !tourOwns,
            narration: bootNarration
        )
        bootNotice.narratedElsewhere = narrated
        if !narrated {
            Task {
                await whatsNew.launched(
                    opensWindow: opensWindow,
                    existingUser: existingUser
                )
            }
        }
    }
}
