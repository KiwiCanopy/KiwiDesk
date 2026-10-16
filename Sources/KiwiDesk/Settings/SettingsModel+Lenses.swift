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

    /// Renames `name`: its chord on this page follows at once, its
    /// stored chords and marks at the Save (`lensPass`).
    @discardableResult
    func renameLens(_ name: String, to raw: String) -> LensNameRefusal? {
        if let refusal = lensNameRefusal(raw, renaming: name) {
            return refusal
        }
        let new = AppWideSettings.lensName(raw)
        guard new != name else { return nil }
        editLenses { edits in
            guard
                let at = edits.lenses.firstIndex(where: {
                    $0.lens.name == name
                })
            else { return }
            edits.lenses[at].lens.name = new
            if let reach = edits.reach.removeValue(forKey: name) {
                edits.reach[new] = reach
            }
        }
        config.layers = KeybindingCatalog.renameLens(
            in: config.layers,
            from: name,
            to: new
        )
        return nil
    }

    /// Deletes `name`, its chord on this page at once, its stored
    /// chords and marks at the Save.
    func deleteLens(_ name: String) {
        editLenses { edits in
            guard
                let at = edits.lenses.firstIndex(where: {
                    $0.lens.name == name
                })
            else { return }
            if let stored = edits.lenses[at].stored {
                edits.deleted.append(stored)
            }
            edits.lenses.remove(at: at)
            edits.reach[name] = nil
        }
        config.layers = KeybindingCatalog.deleteLens(
            in: config.layers,
            named: name
        )
    }

    /// Changes `name`'s apps or settings; a rename is
    /// `renameLens`'s, which the chords follow.
    func updateLens(_ name: String, _ change: (inout VisionLens) -> Void) {
        editLenses { edits in
            guard
                let at = edits.lenses.firstIndex(where: {
                    $0.lens.name == name
                })
            else { return }
            change(&edits.lenses[at].lens)
            edits.lenses[at].lens.name = name
        }
    }

    /// The saved profiles the checklist lists, nil without one.
    var lensProfiles: [String]? { layeredReach?.lensProfiles }

    /// The saved profiles `name` reaches with the draft applied;
    /// a built-in reaches every lens (ruling 38).
    func lensReach(_ name: String) -> Set<String>? {
        layeredReach?.profilesReaching(name)
    }

    /// `name` reaches exactly `reached` of the saved profiles.
    func setLensReach(_ name: String, _ reached: Set<String>) {
        editLenses { $0.reach[name] = reached }
    }

    /// Writes the draft's lenses — the settled list with its edits,
    /// never the live one (ruling 40) — once the rule half, which
    /// carried the chords and marks, has landed. A rename of the
    /// lens on says so, so it follows (`followActiveLens`).
    func saveLensHalf() {
        guard let edits = reachEdits.lenses else { return }
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
