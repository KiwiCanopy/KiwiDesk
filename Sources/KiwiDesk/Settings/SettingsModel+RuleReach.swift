import KiwiDeskCore

/// What a Save's rule half did (#1393).
enum RuleReachWrite: Equatable {
    /// No checklist, or nothing it reaches changed.
    case nothing
    /// Every reached file and the base were written.
    case landed
    /// A write failed; some files may have been written.
    case failed
}

/// Which profiles an App Rule reaches (#1393): the stored table,
/// the draft's choices over it, and the writes a Save owes.
extension SettingsModel {
    /// The profile whose page the checklist is read from — the
    /// edited one, or the loaded one on the live target. nil hides
    /// the column: no profile to name, or no GUI-owned base.
    var reachProfile: String? { reachPage }

    /// Whether the page is the loaded profile's, which decides a
    /// new rule's starting reach.
    var reachIsLoaded: Bool { editingProfile == nil }

    /// The profile the checklist marks "loaded": on the live
    /// target the page's own, pinned with it; on a stored page the
    /// one on screen.
    var reachLoaded: String? { reachIsLoaded ? reachPage : activeProfile }

    /// The stored tables with the draft applied; nil without a
    /// checklist.
    var encodedReach: RuleReachSnapshot? {
        guard var snapshot = ruleReachStored, let editing = reachProfile
        else { return nil }
        var pageTemplates: [String: KeyBinding] = [:]
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
        let pageKeys = RuleReachTable<String>.combos(config.layers)
        RuleReachTable<String>.collectTemplates(
            config.layers,
            into: &pageTemplates
        )
        snapshot.keyTemplates.merge(pageTemplates) { _, page in page }
        snapshot.keyLayers = RuleReachDraft.encode(
            snapshot.keyLayers,
            current: pageKeys,
            editing: editing,
            isLoaded: reachIsLoaded,
            reach: reachEdits.reach[.key] ?? [:],
            removal: reachEdits.removal[.key] ?? [:],
            holdsLeftOut: false
        )
        return snapshot
    }

    /// Seeds the loaded profile's page with the rules it RESOLVES —
    /// the shared ones and its own — so the page shows what the
    /// screen does. The shared rules alone go back to gui.json,
    /// through `sidecarConfig`.
    func resolveLoadedRules(_ config: inout GuiConfig) {
        guard let stored = ruleReachStored, let loaded = reachPage,
            stored.appRules.profiles.contains(loaded)
        else { return }
        config.appRules = stored.appRules.resolved(for: loaded)
        config.floatRules = stored.floatRules.resolved(for: loaded)
            .sorted { $0.key < $1.key }
            .flatMap(\.value)
        config.layers =
            stored.storedKeyOverrides[loaded]?.resolved(
                onto: stored.storedKeyBase
            ) ?? stored.storedKeyBase
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
        sidecar.appRules = reach.appRules.appRuleBase(
            original: reach.storedAppBase
        )
        sidecar.floatRules = reach.floatRules.floatRuleBase(
            original: reach.storedFloatBase
        )
        sidecar.layers = reach.keyLayers.keyLayerBase(
            page: config.layers,
            storedPage: reachPage.flatMap {
                reach.storedKeyOverrides[$0]?.resolved(
                    onto: reach.storedKeyBase
                )
            } ?? reach.storedKeyBase,
            storedBase: reach.storedKeyBase,
            templates: reach.keyTemplates
        )
        return sidecar
    }

    /// Writes every profile file and the shared rules the draft's
    /// checklist reached, and says what happened — the one answer
    /// every Save door reads, so none infers from its own control
    /// flow which half landed. `keysLeftTo` is a stored page, whose
    /// own shortcut override its Save diffs from the page.
    func saveRuleReach(keysLeftTo page: String? = nil) -> RuleReachWrite {
        guard let reach = encodedReach, reach.isEdited else {
            return .nothing
        }
        do {
            try core.saveRuleReach(reach, keysLeftTo: page)
            return .landed
        } catch {
            profileWarning = L(
                "profiles.save_failed",
                "Saving failed: %1$@",
                "\(error)"
            )
            core.onLog("rule reach save failed: \(error)")
            return .failed
        }
    }

    /// Whether Save as new profile… waits: a checklist choice
    /// reaches other profiles, which a copy cannot carry. A plain
    /// value edit is the copy's own.
    var copyWaitsOnReach: Bool { !reachEdits.isEmpty }

    /// Takes a rule half that landed as the draft's baseline, so
    /// only what did not land stays unsaved.
    func adoptRuleHalf() {
        suppressDirty = true
        cleanConfig.appRules = config.appRules
        cleanConfig.floatRules = config.floatRules
        ruleReachStored = core.ruleReachSnapshot()
        reachEdits = RuleReachEdits()
        suppressDirty = false
        recomputeDirty()
    }

    /// Drops the draft's rule half, so a globals write after a
    /// failed or refused rule write carries the stored rules.
    func dropRuleHalf() {
        config.appRules = cleanConfig.appRules
        config.floatRules = cleanConfig.floatRules
        reachEdits = RuleReachEdits()
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
