import Foundation

/// Fired when a gone Space's shortcuts left the base and the
/// profiles (#1827) — a write of every shortcut file, not of the
/// live profile, so an open draft of ANY target takes it
/// (`KiwiCore.onShortcutsDropped`).
public typealias ShortcutsDropped = @MainActor (Set<SpaceID>) -> Void

/// A temporary Space's shortcuts go when it drops, and a held
/// Space's when its hold ends (#1827, amending #92 and #1507's "the
/// chord outlives the Space"): its number was made for it and is
/// minted again later, so a leftover chord would aim at an
/// unrelated Space. The ruling is in `docs/design-decisions.md`.
///
/// The end is recorded where it happens — the one Space drop,
/// `forwardWindows(of:to:)`, and the held go-home arms that clear
/// the hold first — and paid at the next retile, the number staying
/// taken until then (`mintedSpaceNumber`, the hold's renumbers).
extension KiwiCore {
    /// Owes `space`'s shortcuts if it is temporary or held as it
    /// ends; a Space an arrangement declares is never either.
    func oweShortcutDropIfLiveOnly(_ space: SpaceID) {
        guard state.heldSpaces[space] != nil || isTemporary(space)
        else { return }
        oweShortcutDrop(space)
    }

    /// Owes `space`'s shortcuts: its temporary life or hold ended.
    /// Only a Space a live shortcut names owes one — the installed
    /// layers, or the stored base before any are — so an emptied
    /// Space with none frees its number at once (#1790).
    func oweShortcutDrop(_ space: SpaceID) {
        let layers = appliedStructuredLayers ?? baseKeyLayers()
        let named = layers.contains { layer in
            layer.bindings.contains { $0.names([space]) }
        }
        guard named else { return }
        state.owedShortcutDrops.insert(space)
    }

    /// Pays every owed drop once no apply is in flight: each Space
    /// takes every binding naming it — the base and every profile's
    /// override — unless an arrangement declares it, whose binding
    /// is #92's to keep.
    func payOwedShortcutDrops() {
        guard profiles.arrangementInFlight == 0,
            !state.owedShortcutDrops.isEmpty
        else { return }
        let owed = state.owedShortcutDrops
        state.owedShortcutDrops = []
        let declared = profiles.allProfiles().reduce(
            into: Set<SpaceID>()
        ) { $0.formUnion($1.declaredSpaces) }
        let orphaned = owed.filter {
            !declared.contains($0) && !isDeclared($0)
        }
        guard !orphaned.isEmpty else { return }
        dropShortcuts(naming: orphaned)
    }

    /// Rewrites `gui.json`'s layers and every profile override
    /// without a row naming `spaces`, re-registers the shortcuts
    /// and tells an open Settings draft through
    /// `onShortcutsDropped`. A Lua-owned config is `init.lua`'s,
    /// which nothing rewrites.
    func dropShortcuts(naming spaces: Set<SpaceID>) {
        guard isGuiManaged, var sidecar = guiConfigStore.load() else {
            return
        }
        let base = sidecar.layers.removingRows(naming: spaces)
        let baseNames = Set(sidecar.layers.map(\.name))
        var pending: [Profile] = []
        for var profile in profiles.allProfiles() {
            guard let override = profile.layers else { continue }
            let trimmed = override.removingRows(
                naming: spaces,
                baseRemoved: base.removed,
                baseLayers: baseNames
            )
            guard trimmed != override else { continue }
            profile.layers = trimmed
            pending.append(profile)
        }
        guard !base.removed.isEmpty || !pending.isEmpty else { return }
        let names = spaces.map(\.raw).sorted().joined(separator: ", ")
        do {
            for profile in pending { try profiles.write(profile) }
            if !base.removed.isEmpty {
                sidecar.layers = base.layers
                try guiConfigStore.save(sidecar)
            }
        } catch {
            onLog("space \(names) gone: shortcuts not removed: \(error)")
            return
        }
        onLog("space \(names) gone: its shortcuts removed")
        refreshConfigIssues()
        refreshStructuredOverrides(keys: true)
        onShortcutsDropped(spaces)
    }
}
