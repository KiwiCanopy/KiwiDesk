import Foundation

/// The Desktop tier's top-up: each Desktop past the mark gets its
/// `⌃⌥⇧⌘` + digit row in the base layer, at boot and when a switch
/// reveals a Desktop the mark has not reached. The mark is per Mac
/// (`DesktopMemory.shortcutMark`), since the Desktops are.
extension KiwiCore {
    /// Tops up the Desktop rows for `desktops`, the snapshot's user
    /// Desktops. Free once the mark covers them: one defaults read.
    func topUpDesktopShortcuts(desktops: [Int]) {
        let mark = desktopMemory.readShortcutMark()
        let reachable = desktops.filter {
            $0 <= DefaultKeybindings.digitCapacity
        }
        guard let top = reachable.max(), top > mark, isGuiManaged,
            var config = guiConfigStore.load(),
            let index = config.layers.firstIndex(where: { $0.isDefault })
        else { return }
        // A Lua-owned setup leaves the mark where it was, so a later
        // move to Settings still offers these Desktops.
        defer { desktopMemory.writeShortcutMark(top) }
        // A profile's own Desktop row counts as the action bound.
        let overrides = profiles.allProfiles().flatMap {
            $0.layers?.layers.first { $0.isDefault }?.bindings ?? []
        }.filter { $0.lua.hasPrefix("KiwiDesk.focus_desktop(") }
        let added = DefaultKeybindings.desktopTopUp(
            existing: config.layers[index].bindings + overrides,
            desktops: reachable,
            above: mark
        )
        guard !added.isEmpty else { return }
        appendBaseShortcuts(added, to: &config, layer: index)
    }

    /// Appends `rows` to the base layer, saves the sidecar and
    /// re-registers the keys from it, resolving through the live
    /// profile's override as `applyStructuredConfig` does.
    func appendBaseShortcuts(
        _ rows: [KeyBinding],
        to config: inout GuiConfig,
        layer index: Int
    ) {
        config.layers[index].bindings.append(contentsOf: rows)
        try? guiConfigStore.save(config)
        guard let lua = keys.lua else { return }
        applyStructuredKeybindings(
            layers: config.layers,
            profile: activeProfileOverrides()?.layers,
            lua: lua
        )
    }
}
