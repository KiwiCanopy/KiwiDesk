import KiwiDeskCore

/// A lens row's ↺ (#2412): a lens created, deleted or renamed back
/// as stored with its chords, a lens's fields, or one profile's
/// reach — staged through the lens draft as every lens edit is
/// (`editLenses`), its chords against the saved layers.
extension SettingsModel {
    /// Both sides of the lens edit a row names: a row naming one
    /// side of a rename finds the other.
    func lensRevertSides(
        stored: String?,
        page: String?
    ) -> (stored: String?, page: String?) {
        let drafts = reachEdits.lenses?.lenses ?? []
        let page =
            page
            ?? drafts.first { draft in
                draft.stored.map { name in
                    stored.map { AppWideSettings.sameLens(name, $0) } ?? false
                } ?? false
            }?.lens.name
        let stored =
            stored ?? drafts.first { $0.lens.name == page }?.stored
        return (stored, page)
    }

    /// The lens edit a lens's toggle row reverts with: its delete,
    /// rename or creation, nil where the draft leaves it as stored.
    func lensEditRevert(_ name: String) -> SettingsRowRevert? {
        guard let edits = reachEdits.lenses else { return nil }
        let same = { AppWideSettings.sameLens($0, name) }
        // A draft lens holding the name wins over a deleted one of
        // that name, whose ↺ a reused name blocks.
        let draft = edits.lenses.first { draft in
            draft.stored != draft.lens.name
                && (same(draft.lens.name) || draft.stored.map(same) == true)
        }
        if let draft {
            return .lens(stored: draft.stored, page: draft.lens.name)
        }
        return edits.deleted.contains(where: same)
            ? .lens(stored: name, page: nil) : nil
    }

    /// Whether another lens of the page now holds the stored name,
    /// so the lens cannot come back under it; its ↺ is not drawn.
    func lensRevertBlocked(stored: String?, page: String?) -> Bool {
        let sides = lensRevertSides(stored: stored, page: page)
        guard let stored = sides.stored else { return false }
        return draftLenses.contains {
            $0.name != sides.page && AppWideSettings.sameLens($0.name, stored)
        }
    }

    /// The lens a row names back as stored: the page's lens and its
    /// chords go through the delete's own staging, the stored lens
    /// returns at its stored place with its saved chords and the
    /// bindings their chords moved between.
    func revertLens(stored: String?, page: String?) {
        let sides = lensRevertSides(stored: stored, page: page)
        if let page = sides.page { dropDraftLens(page) }
        let seed = core.kiwiVisionStoredLenses
        guard let stored = sides.stored,
            let lens = seed.first(where: { $0.name == stored })
        else { return }
        editLenses { edits in
            edits.deleted.removeAll { AppWideSettings.sameLens($0, stored) }
            let order = seed.map(\.name)
            let rank = order.firstIndex(of: stored) ?? order.count
            let at =
                edits.lenses.firstIndex { draft in
                    (draft.stored.flatMap(order.firstIndex(of:))
                        ?? order.count) > rank
                } ?? edits.lenses.count
            edits.lenses.insert(DraftLens(lens: lens, stored: stored), at: at)
        }
        let back = BindingRevertSet.restoreEverywhere(
            KeybindingCatalog.toggleLens(stored).lua,
            draft: config.layers,
            baseline: revertBaseline,
            saved: savedLayerName
        )
        config.layers = back.layers
        var edits = reachEdits
        Self.dropKeyPicks(back.keys, in: &edits)
        if edits != reachEdits { reachEdits = edits }
    }

    /// The apps and settings of the page's lens `page` back as
    /// stored, its name kept.
    func revertLensFields(page: String) {
        let seed = core.kiwiVisionStoredLenses
        editLenses { edits in
            guard
                let at = edits.lenses.firstIndex(where: {
                    $0.lens.name == page
                }),
                let stored = edits.lenses[at].stored,
                var lens = seed.first(where: { $0.name == stored })
            else { return }
            lens.name = page
            edits.lenses[at].lens = lens
        }
    }

    /// The saved profiles the page's lens `page` reaches without the
    /// draft's own pick for it: its stored reach, or a new lens's
    /// default — the one reading the reach rows, the pick and its
    /// revert compare against.
    func lensReachWithoutPick(_ page: String) -> Set<String>? {
        var bare = reachEdits
        bare.lenses?.reach[page] = nil
        return layeredReach(bare)?.profilesReaching(page)
    }

    /// Whether the page's lens `page` reaches `profile` back to what
    /// it reaches without the draft's pick.
    func revertLensReach(page: String, profile: String) {
        guard let now = lensReach(page),
            let before = lensReachWithoutPick(page)
        else { return }
        var reached = now
        if before.contains(profile) {
            reached.insert(profile)
        } else {
            reached.remove(profile)
        }
        setLensReach(page, reached)
    }
}
