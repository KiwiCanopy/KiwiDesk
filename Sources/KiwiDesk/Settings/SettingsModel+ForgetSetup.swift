import Foundation
import KiwiDeskCore

/// The Known screen setups card's forget (#3324): Core forgets
/// through its one verb, and the open draft follows what that
/// write wrote, so its next Save writes nothing back.
extension SettingsModel {
    /// Parks the forget of `setup` behind its confirm; a setup has
    /// no undo. The connected one never gets here — its ✕ is
    /// greyed, and Core refuses it anyway.
    func confirmingSetupForget(_ setup: KnownMonitorSet) {
        let label = knownSetupLabel(setup)
        pendingDiscard = PendingDiscard(
            kind: .forgetSetup(label: label),
            message: forgetMessage(setup),
            confirmLabel: L("profiles.known.forget.button", "Forget"),
            perform: { [weak self] in self?.forgetSetup(setup) }
        )
    }

    /// The confirm's body: what leaves with the setup, the dormant
    /// sentence where it was its profile's last, and no undo.
    func forgetMessage(_ setup: KnownMonitorSet) -> String {
        var parts = [
            L(
                "profiles.known.forget.confirm.message",
                "This setup leaves “%1$@”, along with its Space pins "
                    + "and its per-screen bar edges. Desktops bound "
                    + "to this setup lose that binding. Your other "
                    + "setups stay as they are.",
                setup.profile
            )
        ]
        if setup.isProfilesLast {
            parts.append(
                L(
                    "profiles.known.forget.confirm.dormant",
                    "“%1$@” keeps its settings, but you'll have to "
                        + "load it by hand until it gets a screen "
                        + "setup again.",
                    setup.profile
                )
            )
        }
        parts.append(
            L("profiles.known.forget.confirm.no_undo", "You can't undo this.")
        )
        return parts.joined(separator: "\n\n")
    }

    /// A setup's name as every other row on the page names it
    /// (`setupLabels`), so one setup never reads two ways.
    func knownSetupLabel(_ setup: KnownMonitorSet) -> String {
        setupLabels([setup.monitors])[0]
    }

    /// Forgets through Core's one forget, as the CLI's verb does,
    /// and narrates a refusal from its case (core-boundaries.md);
    /// the draft follows through `adoptForgottenSetup`, which the
    /// write calls.
    func forgetSetup(_ setup: KnownMonitorSet) {
        do {
            try core.withUserMotion {
                try core.forgetMonitorSet(setup.monitors)
            }
        } catch let refusal as MonitorSetForgetError {
            profileWarning = Self.forgetRefusal(refusal)
        } catch {
            profileWarning = L(
                "profiles.known.forget_failed",
                "Forgetting the screen setup failed: %1$@",
                NewerFormatText.detail(error)
            )
            core.onLog("screen setup forget failed: \(error)")
        }
        refreshProfiles()
    }

    static func forgetRefusal(_ refusal: MonitorSetForgetError) -> String {
        switch refusal {
        case .connected:
            return L(
                "profiles.known.connected.help",
                "Disconnect these screens to forget this setup."
            )
        case .unknown:
            return L(
                "profiles.known.forget_unknown",
                "No profile holds this screen setup any more."
            )
        }
    }

    /// Core forgot `monitors` from `name` (`CapturedWrite`): the
    /// draft and its baseline drop the setup's binding entries,
    /// and, where the draft edits that profile, the bar edges of
    /// screens its remaining setups no longer hold — or the next
    /// Save writes them back. Reached from the window controller,
    /// for a forget from any door.
    func adoptForgottenSetup(_ monitors: [String], from name: String) {
        refreshProfiles()
        config.profileBindings.forgetSetup(monitors)
        cleanConfig.profileBindings.forgetSetup(monitors)
        if (editingProfile ?? core.profiles.currentName) == name {
            let scope = core.screenEdgeScope(monitorSets: draftMonitorSets)
            config.settings.keepScreenEdges(in: scope)
            cleanConfig.settings.keepScreenEdges(in: scope)
        }
        refreshBindingReadings()
        recomputeDirty()
    }
}
