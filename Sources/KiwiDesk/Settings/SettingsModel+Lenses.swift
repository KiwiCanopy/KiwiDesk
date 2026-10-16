import KiwiDeskCore

/// The lens page's draft (#2103 rulings 29, 38, 39): lenses added,
/// renamed, deleted, edited and reached, staged in `reachEdits`
/// until the page's Save, which writes them through
/// `saveLensHalf`. Every name compares through `sameLens`.
extension SettingsModel {
    /// The page's lenses: the draft's, else the stored ones.
    var draftLenses: [VisionLens] {
        reachEdits.lenses?.current ?? core.kiwiVisionStoredLenses
    }

    /// Why `raw` cannot name a lens — `renaming` that lens, or a
    /// new one — nil where it may (ruling 39).
    func lensNameRefusal(
        _ raw: String,
        renaming: String? = nil
    ) -> LensNameRefusal? {
        LensNameRefusal.of(
            raw,
            among: draftLenses.map(\.name).filter { $0 != renaming }
        )
    }

    /// Adds a lens with no apps and no chord (ruling 11).
    @discardableResult
    func addLens(named raw: String) -> LensNameRefusal? {
        if let refusal = lensNameRefusal(raw) { return refusal }
        let lens = VisionLens(name: AppWideSettings.lensName(raw))
        editLenses { $0.lenses.append(DraftLens(lens: lens, stored: nil)) }
        return nil
    }

    /// The page's spelling of `name`, matched as every lens name is
    /// (`sameLens`), nil for a lens the page does not list.
    private func draftName(_ name: String) -> String? {
        draftLenses.first { AppWideSettings.sameLens($0.name, name) }?
            .name
    }

    /// Renames `name`: its chord on this page follows at once, its
    /// stored chords and marks at the Save (`lensPass`). A lens the
    /// page does not list changes nothing.
    @discardableResult
    func renameLens(_ name: String, to raw: String) -> LensNameRefusal? {
        guard let old = draftName(name) else { return nil }
        if let refusal = lensNameRefusal(raw, renaming: old) {
            return refusal
        }
        let new = AppWideSettings.lensName(raw)
        guard new != old else { return nil }
        editLenses { edits in
            guard
                let at = edits.lenses.firstIndex(where: {
                    $0.lens.name == old
                })
            else { return }
            edits.lenses[at].lens.name = new
            if let reach = edits.reach.removeValue(forKey: old) {
                edits.reach[new] = reach
            }
        }
        config.layers = KeybindingCatalog.renameLens(
            in: config.layers,
            from: old,
            to: new
        )
        return nil
    }

    /// Deletes `name`, its chord on this page at once, its stored
    /// chords and marks at the Save.
    func deleteLens(_ name: String) {
        guard let old = draftName(name) else { return }
        editLenses { edits in
            guard
                let at = edits.lenses.firstIndex(where: {
                    $0.lens.name == old
                })
            else { return }
            if let stored = edits.lenses[at].stored {
                edits.deleted.append(stored)
            }
            edits.lenses.remove(at: at)
            edits.reach[old] = nil
        }
        config.layers = KeybindingCatalog.deleteLens(
            in: config.layers,
            named: old
        )
    }

    /// Changes `name`'s apps or settings; a rename is
    /// `renameLens`'s, which the chords follow.
    func updateLens(_ name: String, _ change: (inout VisionLens) -> Void) {
        guard let old = draftName(name) else { return }
        editLenses { edits in
            guard
                let at = edits.lenses.firstIndex(where: {
                    $0.lens.name == old
                })
            else { return }
            change(&edits.lenses[at].lens)
            edits.lenses[at].lens.name = old
        }
    }

    /// The saved profiles the checklist lists, nil without one.
    var lensProfiles: [String]? { layeredReach?.lensProfiles }

    /// The saved profiles `name` reaches with the draft applied;
    /// a built-in reaches every lens (ruling 38).
    func lensReach(_ name: String) -> Set<String>? {
        layeredReach?.profilesReaching(name)
    }

    /// `name` reaches exactly `reached` of the saved profiles; a
    /// pick of a stored lens's own reach is no edit.
    func setLensReach(_ name: String, _ reached: Set<String>) {
        guard let page = draftName(name) else { return }
        editLenses { edits in
            let stored = edits.lenses.first { $0.lens.name == page }?.stored
            let before = stored.flatMap {
                ruleReachStored?.profilesReaching($0)
            }
            edits.reach[page] = before == reached ? nil : reached
        }
    }

    /// Writes the draft's lenses — the settled list with its
    /// edits, never the live one (ruling 40) — once the rule half,
    /// which carried the chords and marks, has landed. Live takes
    /// the same edits, a session lens kept beside them, until the
    /// Save's config reload makes the stored list live, as after
    /// any Save. A rename of the lens on says so, so it follows
    /// (`followActiveLens`). Called by `saveRuleReach` alone, so
    /// every Save door carries it.
    func saveLensHalf() {
        // A Lua-owned setup has no store to write (its page greys).
        guard let edits = reachEdits.lenses, core.isGuiManaged else {
            return
        }
        let active = core.kiwiVisionActive.lensName
        let follow = active.flatMap { name in
            edits.renames.first { AppWideSettings.sameLens($0.key, name) }
        }
        core.withUserMotion {
            core.setAppWide(
                persisting: true,
                renamingLens: follow.map { (from: $0.key, to: $0.value) }
            ) {
                $0.visionLenses = edits.applied(to: $0.visionLenses)
            }
        }
    }

    /// Edits the draft, dropping it once it changes nothing.
    private func editLenses(_ change: (inout LensEdits) -> Void) {
        let stored = core.kiwiVisionStoredLenses
        var edits = reachEdits.lenses ?? LensEdits(stored: stored)
        change(&edits)
        reachEdits.lenses = edits.isInert(over: stored) ? nil : edits
    }
}
