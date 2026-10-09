import Foundation

/// A temporary Space's shortcuts go when it drops, and a held
/// Space's when its hold ends (#1827, amending #92 and #1507's "the
/// chord outlives the Space"): its number was made for it and is
/// minted again later, so a leftover chord would aim at an
/// unrelated Space. The ruling is in `docs/design-decisions.md`.
extension KiwiCore {
    /// The one drop path, at the retile every membership change
    /// takes: each Space temporary or held at the last retile and
    /// gone now takes every binding naming it — the base and every
    /// profile's override — unless an arrangement still declares
    /// it, whose binding is #92's to keep. A Space that went home
    /// or into the profile is live and keeps its own.
    func retireLiveOnlyShortcuts() {
        guard profiles.arrangementInFlight == 0 else { return }
        let gone = state.liveOnlyAtLastRetile.filter {
            state.workspaces[$0] == nil
        }
        state.liveOnlyAtLastRetile = Set(liveTemporarySpaces)
            .union(state.heldSpaces.keys)
        guard !gone.isEmpty else { return }
        let declared = profiles.allProfiles().reduce(
            into: Set<SpaceID>()
        ) { $0.formUnion($1.declaredSpaces) }
        let orphaned = gone.filter {
            !declared.contains($0) && !isDeclared($0)
        }
        guard !orphaned.isEmpty else { return }
        dropShortcuts(naming: orphaned)
    }

    /// Rewrites `gui.json`'s layers and every profile override
    /// without a row naming `spaces`, re-registers the shortcuts
    /// and hands an open Settings draft the same edit. A
    /// Lua-owned config is `init.lua`'s, which nothing rewrites.
    func dropShortcuts(naming spaces: Set<SpaceID>) {
        guard isGuiManaged, var sidecar = guiConfigStore.load() else {
            return
        }
        let base = sidecar.layers.removingRows(naming: spaces)
        var pending: [Profile] = []
        for var profile in profiles.allProfiles() {
            guard let override = profile.layers else { continue }
            let trimmed = override.removingRows(
                naming: spaces,
                baseRemoved: base.removed
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
        onLiveProfileWritten(.dropSpaceShortcuts(spaces), true)
    }
}
