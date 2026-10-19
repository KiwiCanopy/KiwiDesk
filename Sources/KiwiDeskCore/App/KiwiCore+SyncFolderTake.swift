import Foundation

/// What a sync take replaces beside its bundle (#2324 slice 2).
struct SyncTake {
    /// The staged copy of the folder's `init.lua`, nil where the
    /// folder has none, which leaves this Mac without one.
    let initLua: URL?
    /// Whether the folder's own setup is the GUI's: `gui.json`
    /// beside an `init.lua` with no foreign code. Judged on the
    /// incoming files, since the take replaces this Mac's.
    let guiManaged: Bool
}

/// Keep the Folder's (#2324 slice 2): the folder's setup replaces
/// this Mac's through the backup restore, whose ordering prunes
/// live state before the reload (#606).
extension KiwiCore {
    /// Replaces this Mac's setup with `folder`'s, this Mac's going
    /// to `trash`, then reloads. This Mac's Desktop bindings stay:
    /// they name this Mac's Desktops (#2324 ruling 12).
    ///
    /// The folder is read through a scratch copy, so a migration
    /// the read applies rewrites the copy, never the folder. Only a
    /// `.copy(.couldNotWrite)` is thrown after this Mac's setup was
    /// touched; every other refusal comes before.
    @discardableResult
    public func keepFoldersSetup(
        from folder: URL,
        trash: (URL) throws -> Void
    ) throws(SyncRefusal) -> RestoreOutcome {
        let side = SyncFolder.side(in: folder, mac: nil)
        if let refusal = refusalBeforeReading(folder, side) {
            throw refusal
        }
        // One scratch copy serves the wholeness check and the take.
        let stage = try staged(folder)
        defer { try? FileManager.default.removeItem(at: stage) }
        guard stagedIsWhole(stage) else { throw .folderUnreadable }
        let bundle = try stagedBundle(in: stage)
        let lua = stage.appendingPathComponent(SyncFolder.initLua)
        let hasLua = FileManager.default.fileExists(atPath: lua.path)
        let take = SyncTake(
            initLua: hasLua ? lua : nil,
            guiManaged: bundle.config != nil
                && !Self.foreignCode(at: lua)
        )
        do {
            return try replaceSetup(with: bundle, trash: trash, take: take)
        } catch {
            throw .copy(error)
        }
    }

    /// Whether `folder`'s setup reads whole, judged on a scratch
    /// copy (`stagedIsWhole`).
    func folderIsWhole(_ folder: URL) -> Bool {
        guard let stage = try? staged(folder) else { return false }
        defer { try? FileManager.default.removeItem(at: stage) }
        return stagedIsWhole(stage)
    }

    /// Whether a staged setup reads whole: its bundle builds, every
    /// profile decodes, and there are settings for them — `gui.json`,
    /// or an `init.lua` that owns the setup itself.
    private func stagedIsWhole(_ stage: URL) -> Bool {
        guard (try? stagedBundle(in: stage)) != nil else { return false }
        let profiles = ProfileManager(
            directory: stage.appendingPathComponent(
                SyncFolder.name(of: .profiles)
            )
        )
        let decodes = profiles.scan().allSatisfy {
            if case .success = $0.1 { return true }
            return false
        }
        let gui = stage.appendingPathComponent(
            SyncFolder.name(of: .guiConfig)
        )
        let lua = stage.appendingPathComponent(SyncFolder.initLua)
        let settled =
            FileManager.default.fileExists(atPath: gui.path)
            || Self.foreignCode(at: lua)
        return decodes && settled
    }

    /// Copies the staged `init.lua` in place of this Mac's, which
    /// the replace has already discarded. False where it failed.
    func copyInitLua(_ take: SyncTake) -> Bool {
        guard let staged = take.initLua else { return true }
        do {
            try FileManager.default.copyItem(at: staged, to: configURL)
            return true
        } catch {
            onLog("sync: could not copy init.lua: \(error)")
            return false
        }
    }

    // MARK: - Staging

    /// A scratch copy of `folder`'s setup files.
    private func staged(_ folder: URL) throws(SyncRefusal) -> URL {
        let files = FileManager.default
        let stage = files.temporaryDirectory.appendingPathComponent(
            "kiwidesk-sync-\(UUID().uuidString)"
        )
        do {
            try files.createDirectory(
                at: stage,
                withIntermediateDirectories: true
            )
            for name in SyncFolder.setupNames {
                let from = folder.appendingPathComponent(name)
                guard files.fileExists(atPath: from.path) else {
                    continue
                }
                try files.copyItem(
                    at: from,
                    to: stage.appendingPathComponent(name)
                )
            }
        } catch {
            try? files.removeItem(at: stage)
            onLog("sync: could not read the folder: \(error)")
            throw .folderUnreadable
        }
        return stage
    }

    /// The staged folder read as a bundle by the export's own
    /// builder; the bindings stay this Mac's, so it carries none.
    private func stagedBundle(
        in stage: URL
    ) throws(SyncRefusal) -> SetupBundle {
        let gui = GuiConfigStore(
            directory: stage,
            machine: stage.appendingPathComponent("machine")
        )
        if gui.exists, gui.load() == nil { throw .folderUnreadable }
        guard
            let bundle = try? Self.setupBundle(
                gui: gui,
                profiles: ProfileManager(
                    directory: stage.appendingPathComponent(
                        SyncFolder.name(of: .profiles)
                    )
                ),
                palettes: PaletteStore(directory: stage),
                looks: LookStore(directory: stage),
                bindings: false
            )
        else { throw .folderUnreadable }
        return bundle
    }

    static func foreignCode(at url: URL) -> Bool {
        guard let source = try? String(contentsOf: url, encoding: .utf8)
        else { return false }
        return ManagedConfig.hasForeignCode(source)
    }
}
