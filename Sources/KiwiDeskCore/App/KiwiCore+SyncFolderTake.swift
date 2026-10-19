import Foundation

/// Keep the Folder's (#2324 slice 2): the folder's setup replaces
/// this Mac's through the backup restore, whose ordering prunes
/// live state before the reload (#606).
extension KiwiCore {
    /// Replaces this Mac's setup with `folder`'s, this Mac's going
    /// to `trash`, then reloads. This Mac's Desktop bindings stay:
    /// they name this Mac's Desktops (#2324 ruling 12).
    ///
    /// The folder is read through a scratch copy, so a migration
    /// the read applies rewrites the copy, never the folder.
    @discardableResult
    public func keepFoldersSetup(
        from folder: URL,
        trash: (URL) throws -> Void
    ) throws(SyncRefusal) -> RestoreOutcome {
        let side = SyncFolder.side(in: folder, mac: nil)
        if let refusal = keepFolderRefusal(folder, side) {
            throw refusal
        }
        let files = FileManager.default
        let stage = files.temporaryDirectory.appendingPathComponent(
            "kiwidesk-sync-\(UUID().uuidString)"
        )
        defer { try? files.removeItem(at: stage) }
        do {
            try files.createDirectory(
                at: stage,
                withIntermediateDirectories: true
            )
        } catch {
            throw .copy(.unreadable)
        }
        try replaceSetupFiles(in: stage, from: folder) { _ in }
        let bundle = try stagedBundle(in: stage)
        let lua = stage.appendingPathComponent(SyncFolder.initLua)
        do {
            return try replaceSetup(with: bundle, trash: trash) {
                () throws(SetupBundleError) in
                try replaceInitLua(with: lua, trash: trash)
            }
        } catch {
            throw .copy(error)
        }
    }

    /// The staged folder read as a bundle. Every artifact is
    /// replaced, absent ones by nothing, since nothing merges.
    private func stagedBundle(
        in stage: URL
    ) throws(SyncRefusal) -> SetupBundle {
        let gui = GuiConfigStore(
            directory: stage,
            machine: stage.appendingPathComponent("machine")
        )
        let config = gui.load()
        if gui.exists, config == nil { throw .copy(.unreadable) }
        let profiles = ProfileManager(
            directory: stage.appendingPathComponent(
                SyncFolder.name(of: .profiles)
            )
        ).allProfiles()
        guard
            let palettes = try? PaletteStore(directory: stage)
                .libraryPalettes(),
            let looks = try? LookStore(directory: stage).libraryLooks()
        else { throw .copy(.unreadable) }
        return SetupBundle(
            writtenBy: KiwiDeskVersion.semantic,
            config: config,
            profiles: profiles,
            palettes: palettes,
            looks: looks,
            profileBindings: config == nil
                ? nil : guiConfigStore.load()?.profileBindings ?? [:]
        )
    }

    /// Puts `staged` in place of this Mac's `init.lua`, which goes
    /// to `trash`; a folder without one leaves this Mac without one.
    private func replaceInitLua(
        with staged: URL,
        trash: (URL) throws -> Void
    ) throws(SetupBundleError) {
        let files = FileManager.default
        do {
            try discard(configURL, trash)
        } catch {
            throw .couldNotWrite(name: SyncFolder.initLua)
        }
        guard files.fileExists(atPath: staged.path) else { return }
        do {
            try files.copyItem(at: staged, to: configURL)
        } catch {
            onLog("sync: could not copy init.lua: \(error)")
            throw .couldNotWrite(name: SyncFolder.initLua)
        }
    }
}
