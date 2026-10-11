import Foundation

/// The seed's two top-ups: the Space digit rows (#485) and the
/// Desktop tier's `⌃⌥⇧⌘` + digit rows. Both are additive and
/// GUI-managed only, append through `appendBaseShortcuts`, and tell
/// an open Settings draft what they added.
extension KiwiCore {
    /// Adds ⌃⌥N digit shortcuts for spaces that appeared after the
    /// first-run seed authored them — the display-change twin of
    /// `seedDefaultShortcuts` (#485). Strictly additive and
    /// GUI-managed only: a Lua user owns their bindings, and a
    /// digit already bound (a seeded default OR a custom chord) is
    /// never rewritten (see `DefaultKeybindings.digitTopUp`), so it
    /// respects the ten-cap accepted limitation and can't clobber a
    /// user shortcut. Writes the sidecar directly and re-registers
    /// the base bindings in place — NOT `saveGuiConfig`, which
    /// would reload the whole config mid-change (mirrors
    /// `syncGuiSpacesToLive`). A no-op when nothing grew, so it is
    /// safe to call after any GUI-managed apply.
    func topUpDigitShortcuts() {
        guard isGuiManaged, var config = guiConfigStore.load(),
            let index = config.layers.firstIndex(
                where: { $0.isDefault }
            )
        else { return }
        let spaces = SpaceID.deduplicated(
            state.workspaces.allSpaces.map(\.id)
        )
        let base = config.layers[index].bindings
        // More existing rows only shrink what is added, so the base
        // alone answers "nothing to add" without reading a profile.
        guard
            !DefaultKeybindings.digitTopUp(
                existing: base,
                spaces: spaces
            ).isEmpty
        else { return }
        // The base is shared by every profile, so a row in it or
        // in ANY profile's override counts: a tombstoned base row
        // still holds its combo, and no profile's resolved layer
        // may end up with a second chord for one verb.
        // Only an override's Space-verb rows: its other combos
        // replace the base's in that profile alone.
        let overrides = profiles.allProfiles().flatMap {
            $0.layers?.layers.first { $0.isDefault }?.bindings ?? []
        }.filter { SpaceLuaArg.target(of: $0.lua) != nil }
        let added = DefaultKeybindings.digitTopUp(
            existing: base + overrides,
            spaces: spaces
        )
        guard !added.isEmpty else { return }
        appendBaseShortcuts(added, to: &config, layer: index)
    }

    /// Tops up the Desktop rows for `desktops`, the snapshot's user
    /// Desktops: each Desktop past the per-Mac mark gets its row
    /// when no row goes there and the chord is free. A Desktop at
    /// or below the mark was offered before, so a row the user
    /// deleted stays deleted. The mark advances only once the rows
    /// landed; a setup that declines (Lua-owned, no sidecar) is
    /// latched for the session instead.
    func topUpDesktopShortcuts(desktops: [Int]) {
        let reachable = desktops.filter {
            $0 <= DefaultKeybindings.digitCapacity
        }
        guard let top = reachable.max(),
            top > desktopMemory.shortcutTopUpDeclined
        else { return }
        let mark = desktopMemory.readShortcutMark()
        guard top > mark else { return }
        guard isGuiManaged, var config = guiConfigStore.load(),
            let index = config.layers.firstIndex(where: { $0.isDefault })
        else {
            desktopMemory.shortcutTopUpDeclined = top
            return
        }
        // A profile's own Desktop row counts as the action bound.
        let overrides = profiles.allProfiles().flatMap {
            $0.layers?.layers.first { $0.isDefault }?.bindings ?? []
        }.filter { DefaultKeybindings.isDesktopRow($0) }
        let added = DefaultKeybindings.desktopTopUp(
            existing: config.layers[index].bindings + overrides,
            desktops: reachable,
            above: mark
        )
        if added.isEmpty
            || appendBaseShortcuts(added, to: &config, layer: index)
        {
            desktopMemory.writeShortcutMark(top)
        }
    }

    /// Appends `rows` to the base layer, saves the sidecar,
    /// re-registers the keys from it — resolving through the live
    /// profile's override as `applyStructuredConfig` does — and
    /// hands the rows to an open draft. False when the save failed.
    @discardableResult
    func appendBaseShortcuts(
        _ rows: [KeyBinding],
        to config: inout GuiConfig,
        layer index: Int
    ) -> Bool {
        config.layers[index].bindings.append(contentsOf: rows)
        do {
            try guiConfigStore.save(config)
        } catch {
            onLog("shortcut top-up not saved: \(error)")
            return false
        }
        if let lua = keys.lua {
            applyStructuredKeybindings(
                layers: config.layers,
                profile: activeProfileOverrides()?.layers,
                lua: lua
            )
        }
        onShortcutsAdded(rows)
        return true
    }
}
