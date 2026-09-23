import KiwiDeskCore

/// Which profiles an App Rule reaches (#1393): the stored table,
/// the draft's choices over it, and the writes a Save owes.
extension SettingsModel {
    /// The profile whose page the checklist is read from — the
    /// edited one, or the loaded one on the live target. nil hides
    /// the column: no profile to name, or no GUI-owned base.
    var reachProfile: String? {
        guard ruleReachStored != nil else { return nil }
        return editingProfile ?? core.profiles.currentName
    }

    /// Whether the page is the loaded profile's, which decides a
    /// new rule's starting reach.
    var reachIsLoaded: Bool { editingProfile == nil }

    /// The stored tables with the draft applied; nil without a
    /// checklist.
    var encodedReach: RuleReachSnapshot? {
        guard var snapshot = ruleReachStored, let editing = reachProfile
        else { return nil }
        snapshot.appRules = RuleReachDraft.encode(
            snapshot.appRules,
            current: AppRuleOverride.normalized(config.appRules),
            editing: editing,
            isLoaded: reachIsLoaded,
            reach: reachEdits.reach[.space] ?? [:],
            removal: reachEdits.removal[.space] ?? [:]
        )
        snapshot.floatRules = RuleReachDraft.encode(
            snapshot.floatRules,
            current: RuleReachTable<[String]>.groupedByApp(
                config.floatRules
            ),
            editing: editing,
            isLoaded: reachIsLoaded,
            reach: reachEdits.reach[.float] ?? [:],
            removal: reachEdits.removal[.float] ?? [:]
        )
        return snapshot
    }

    /// Seeds the loaded profile's page with the rules it RESOLVES —
    /// the shared ones and its own — so the page shows what the
    /// screen does. The shared rules alone go back to gui.json,
    /// through `sidecarConfig`.
    func resolveLoadedRules(_ config: inout GuiConfig) {
        guard let stored = ruleReachStored,
            let loaded = core.profiles.currentName,
            stored.appRules.profiles.contains(loaded)
        else { return }
        config.appRules = stored.appRules.resolved(for: loaded)
        config.floatRules = stored.floatRules.resolved(for: loaded)
            .sorted { $0.key < $1.key }
            .flatMap(\.value)
    }

    /// The draft as gui.json must hold it: on the live target the
    /// page's rules are the loaded profile's resolved set, so the
    /// shared rules are swapped back in. Every gui.json write of
    /// the draft goes through this.
    var sidecarConfig: GuiConfig {
        guard target == .live, let reach = encodedReach else {
            return config
        }
        var sidecar = config
        sidecar.appRules = reach.appRules.base
        sidecar.floatRules = reach.floatRules.floatRuleBase(
            original: reach.storedFloatBase
        )
        return sidecar
    }

    /// Writes every profile file and the shared rules the draft's
    /// checklist reached. `rewriting` is the stored profile a Save
    /// just rewrote by diff (`saveEditedProfile`).
    func saveRuleReach(rewriting name: String? = nil) {
        guard let reach = encodedReach else { return }
        do {
            try core.saveRuleReach(reach, rewriting: name)
        } catch {
            profileWarning = L(
                "profiles.save_failed",
                "Saving failed: %1$@",
                "\(error)"
            )
            core.onLog("rule reach save failed: \(error)")
        }
    }

    /// Profiles in the order the edit-target menu lists them: the
    /// loaded one first, then the connected screen count's, then
    /// the rest by count, each in saved order.
    var profileMenuOrder: [String] {
        let loaded = activeProfile
        let connected = displays.count
        let rest = profileSummaries.filter { $0.name != loaded }
        let ordered = rest.enumerated().sorted { lhs, rhs in
            let l = lhs.element.count
            let r = rhs.element.count
            if (l == connected) != (r == connected) {
                return l == connected
            }
            if l != r { return l > r }
            return lhs.offset < rhs.offset
        }.map(\.element.name)
        return (loaded.map { [$0] } ?? []) + ordered
    }
}
