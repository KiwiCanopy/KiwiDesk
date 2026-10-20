import Foundation

/// The seed's three top-ups: the Space digit rows (#485), the
/// Desktop tier's rows on its stored base and the rows a release added
/// (#2211). All three are additive and
/// GUI-managed only, append through `appendBaseShortcuts`, and tell
/// an open Settings draft what they added. None runs inside the
/// door a synced change enters by (`adoptSyncedChange`, #2324):
/// the Mac that made the change already offered what it needed.
extension KiwiCore {
    /// Adds digit shortcuts, on the stored `shortcutBase` (#2460),
    /// for spaces that appeared after the
    /// first-run seed authored them — the display-change twin of
    /// `seedDefaultShortcuts` (#485). Strictly additive and
    /// GUI-managed only: a Lua user owns their bindings, and a
    /// digit already bound (a seeded default OR a custom chord) is
    /// never rewritten (see `DefaultKeybindings.digitTopUp`), so it
    /// respects the ten-cap accepted limitation and can't clobber a
    /// user shortcut. Writes the sidecar directly and re-registers
    /// the base bindings in place — NOT `saveGuiConfig`, which
    /// would reload the whole config mid-change. A no-op when
    /// nothing grew, so it is safe to call after any GUI-managed
    /// apply.
    func topUpDigitShortcuts() {
        guard sync.adopting == 0, isGuiManaged,
            var config = guiConfigStore.load(),
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
                spaces: spaces,
                base: config.shortcutBase
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
            spaces: spaces,
            base: config.shortcutBase
        )
        guard !added.isEmpty else { return }
        appendBaseShortcuts(added, to: &config, layer: index)
    }

    /// Tops up the Desktop rows for `desktops`, the snapshot's user
    /// Desktops: each Desktop past the setup's offer gets its row,
    /// on the stored `shortcutBase` (#2460), when no row
    /// goes there and the chord is free. A Desktop at or below the
    /// offer was offered before — on this Mac or another sharing
    /// the setup (#2324) — so a row the user deleted stays deleted.
    /// The offer advances only once the rows landed; a setup that
    /// declines (Lua-owned, no sidecar) is latched for the session.
    func topUpDesktopShortcuts(desktops: [Int]) {
        let reachable = desktops.filter {
            $0 <= DefaultKeybindings.digitCapacity
        }
        guard sync.adopting == 0, let top = reachable.max(),
            top > desktopMemory.shortcutTopUpDeclined,
            top > desktopMemory.knownShortcutOffer?.desktop ?? 0
        else { return }
        guard isGuiManaged, var config = guiConfigStore.load(),
            let index = config.layers.firstIndex(where: { $0.isDefault })
        else {
            desktopMemory.shortcutTopUpDeclined = top
            return
        }
        let offer = shortcutOffer(of: config)
        guard top > offer.desktop else { return }
        // A profile's own Desktop row counts as the action bound.
        let overrides = profiles.allProfiles().flatMap {
            $0.layers?.layers.first { $0.isDefault }?.bindings ?? []
        }.filter { DefaultKeybindings.isDesktopRow($0) }
        let added = DefaultKeybindings.desktopTopUp(
            existing: config.layers[index].bindings + overrides,
            desktops: reachable,
            above: offer.desktop,
            base: config.shortcutBase
        )
        config.shortcutOffer = offer.merged(ShortcutOffer(desktop: top))
        saveOffer(added, to: &config, layer: index)
    }

    /// Adds the default rows of every generation this setup has not
    /// been offered (#2211, #2324), where the action is unbound and
    /// the chord free. The offer advances only once the rows
    /// landed; a declining setup (Lua-owned, no sidecar) is asked
    /// again on the next launch.
    func topUpGenerationShortcuts() {
        let newest = DefaultKeybindings.newestGeneration
        guard sync.adopting == 0,
            desktopMemory.knownShortcutOffer?.generation ?? 0 < newest,
            isGuiManaged, var config = guiConfigStore.load(),
            let index = config.layers.firstIndex(where: { $0.isDefault })
        else { return }
        let offer = shortcutOffer(of: config)
        guard offer.generation < newest else { return }
        // A profile's own row for one of these actions counts.
        let offered = Set(
            (1...newest).flatMap {
                DefaultKeybindings.rows(ofGeneration: $0).map(\.lua)
            }
        )
        let overrides = profiles.allProfiles().flatMap {
            $0.layers?.layers.first { $0.isDefault }?.bindings ?? []
        }.filter { offered.contains($0.lua) }
        let added = DefaultKeybindings.generationTopUp(
            existing: config.layers[index].bindings + overrides,
            above: offer.generation,
            base: config.shortcutBase
        )
        config.shortcutOffer = offer.merged(
            ShortcutOffer(generation: newest)
        )
        saveOffer(added, to: &config, layer: index)
    }

    /// Writes `config`'s offer — with `rows` appended where there
    /// are any — and, once it landed, retires the copy a build
    /// before #2324 kept in this Mac's defaults.
    private func saveOffer(
        _ rows: [KeyBinding],
        to config: inout GuiConfig,
        layer index: Int
    ) {
        if rows.isEmpty {
            do {
                try guiConfigStore.save(config)
            } catch {
                onLog("shortcut offer not saved: \(error)")
                return
            }
        } else {
            guard appendBaseShortcuts(rows, to: &config, layer: index)
            else { return }
        }
        desktopMemory.knownShortcutOffer = config.shortcutOffer
        desktopMemory.clearLegacyShortcutOffer()
    }

    /// The offer `config` records, raised by this Mac's pre-#2324
    /// marks until they cross into the file.
    func shortcutOffer(of config: GuiConfig) -> ShortcutOffer {
        let offer = (config.shortcutOffer ?? ShortcutOffer())
            .merged(desktopMemory.readLegacyShortcutOffer())
        desktopMemory.knownShortcutOffer = offer
        return offer
    }

    /// Carries this Mac's pre-#2324 marks into `gui.json` once, so
    /// the file — not the Mac — says what the setup was offered.
    /// A Lua-owned setup keeps them in the defaults.
    func crossLegacyShortcutOffer() {
        guard sync.adopting == 0,
            desktopMemory.readLegacyShortcutOffer() != nil,
            isGuiManaged, var config = guiConfigStore.load()
        else { return }
        config.shortcutOffer = shortcutOffer(of: config)
        do {
            try guiConfigStore.save(config)
        } catch {
            onLog("shortcut offer not carried: \(error)")
            return
        }
        desktopMemory.clearLegacyShortcutOffer()
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
