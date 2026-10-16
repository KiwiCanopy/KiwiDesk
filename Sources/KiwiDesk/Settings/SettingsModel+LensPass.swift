import KiwiDeskCore

/// The lens page's crossings over the stored files (#2103 rulings
/// 38, 39), laid by the one layer pass AHEAD of the row encode
/// (#2022): a deleted lens frees every stored chord and mark
/// naming it, a renamed one re-keys them, and an "Applies to" pick
/// rewrites every profile's `lens_reach`.
extension SettingsModel {
    func lensPass(
        _ snapshot: inout RuleReachSnapshot,
        _ edits: LensEdits
    ) throws {
        if !edits.deleted.isEmpty {
            let deleted = edits.deleted
            try rewriteLensHolders(&snapshot, naming: deleted) { layers in
                deleted.reduce(layers) {
                    KeybindingCatalog.deleteLens(in: $0, named: $1)
                }
            }
            snapshot.deleteLenses(deleted)
        }
        let renames = edits.renames
        if !renames.isEmpty {
            try rewriteLensHolders(
                &snapshot,
                naming: Array(renames.keys)
            ) {
                KeybindingCatalog.renameLenses(in: $0, renames)
            }
            snapshot.renameLenses(renames)
        }
        for (lens, reached) in edits.reach.sorted(by: { $0.key < $1.key }) {
            snapshot.setLensReach(lens, reached: reached)
        }
    }

    /// Rewrites, through `transform`, the base and each profile
    /// whose layers hold a chord for one of `lenses` — and only
    /// those, so a file no chord names is not re-encoded.
    private func rewriteLensHolders(
        _ snapshot: inout RuleReachSnapshot,
        naming lenses: [String],
        _ transform: @escaping ([KeyLayer]) -> [KeyLayer]
    ) throws {
        func holds(_ layers: [KeyLayer]) -> Bool {
            layers.contains { layer in
                layer.bindings.contains { binding in
                    lenses.contains { KeybindingCatalog.names(binding, $0) }
                }
            }
        }
        let holders = snapshot.keyLayers.profiles.filter {
            holds(snapshot.storedKeyLayers(for: $0))
        }
        let inBase = holds(snapshot.storedKeyBase)
        guard !holders.isEmpty || inBase else { return }
        try snapshot.rewriteLayers(
            Dictionary(uniqueKeysWithValues: holders.map { ($0, transform) }),
            base: inBase ? transform : nil
        )
    }
}
