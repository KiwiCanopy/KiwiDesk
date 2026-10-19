import Foundation
import SystemConfiguration

/// Compare and Copy (#2324 slice 2): one whole setup copied between
/// the config folder and a sync folder, in the direction the user
/// picks. The side being replaced goes to the Trash; nothing merges.
///
/// The folder is whatever the user's sync app keeps up to date, so
/// KiwiDesk only reads it here and writes it in Keep This Mac's —
/// no load of the folder migrates or rewrites a file in it.
extension KiwiCore {
    /// Both sides of `folder`'s comparison, and what refuses each
    /// direction. Reads files only.
    public func compareSync(with folder: URL) -> SyncComparison {
        let folderSide = SyncFolder.side(
            in: folder,
            mac: SyncFolder.stampedMac(in: folder)
        )
        return SyncComparison(
            thisMac: SyncFolder.side(
                in: configDirectory,
                mac: Self.thisMacName()
            ),
            folder: folderSide,
            keepThisMacRefusal: keepThisMacRefusal(folder),
            keepFolderRefusal: keepFolderRefusal(folder, folderSide)
        )
    }

    /// Keep This Mac's: replaces the folder's setup with this
    /// Mac's, the folder's going to `trash`, and stamps this Mac's
    /// name into the folder. Changes nothing on this Mac.
    ///
    /// `trash` has no default, as every discard's does not.
    public func keepThisMacsSetup(
        in folder: URL,
        trash: (URL) throws -> Void
    ) throws(SyncRefusal) {
        if let refusal = keepThisMacRefusal(folder) { throw refusal }
        try replaceSetupFiles(
            in: folder,
            from: configDirectory,
            trash: trash
        )
        guard let mac = Self.thisMacName(),
            let data = try? JSONEncoder().encode(SyncStamp(mac: mac))
        else { return }
        do {
            try data.write(
                to: folder.appendingPathComponent(SyncFolder.stampName),
                options: .atomic
            )
        } catch {
            onLog("sync: could not stamp the folder: \(error)")
        }
    }

    /// This Mac's name as Sharing shows it, nil where unreadable.
    public static func thisMacName() -> String? {
        SCDynamicStoreCopyComputerName(nil, nil) as String?
    }

    // MARK: - Refusals

    public func syncFolderRefusal(_ folder: URL) -> SyncRefusal? {
        var isDirectory: ObjCBool = false
        guard
            FileManager.default.fileExists(
                atPath: folder.path,
                isDirectory: &isDirectory
            ), isDirectory.boolValue
        else { return .folderUnavailable }
        if folder.resolvingSymlinksInPath().standardizedFileURL
            == configDirectory.resolvingSymlinksInPath()
            .standardizedFileURL
        {
            return .sameFolder
        }
        return SyncFolder.newerFormat(in: folder).map {
            .folderNewer($0)
        }
    }

    /// The export's own refusals (#606): a file this Mac cannot
    /// read would travel as a setup nobody can open.
    func keepThisMacRefusal(_ folder: URL) -> SyncRefusal? {
        if let refusal = syncFolderRefusal(folder) { return refusal }
        if guiConfigStore.exists, guiConfigStore.load() == nil {
            return .copy(.unreadableSettings)
        }
        if (try? paletteLibrary.libraryPalettes()) == nil {
            return .copy(.unreadablePalettes)
        }
        if (try? lookLibrary.libraryLooks()) == nil {
            return .copy(.unreadableLooks)
        }
        return nil
    }

    func keepFolderRefusal(
        _ folder: URL,
        _ side: SyncSide
    ) -> SyncRefusal? {
        if let refusal = syncFolderRefusal(folder) { return refusal }
        if side.isEmpty { return .folderEmpty }
        if let latch = guiConfigWriteLatch()
            ?? paletteLibrary.newerFormat()
            ?? lookLibrary.newerFormat()
        {
            return .thisMacNewer(latch)
        }
        let carriesSettings = FileManager.default.fileExists(
            atPath: folder.appendingPathComponent(
                SyncFolder.name(of: .guiConfig)
            ).path
        )
        if carriesSettings, !isGuiManaged {
            return .copy(.luaOwnsThisMac)
        }
        return nil
    }

    // MARK: - Files

    /// Trashes every setup file `target` holds, its stamp included,
    /// then copies `source`'s in. A removal that fails refuses
    /// before anything is copied, or a replace would merge.
    func replaceSetupFiles(
        in target: URL,
        from source: URL,
        trash: (URL) throws -> Void
    ) throws(SyncRefusal) {
        let files = FileManager.default
        for name in SyncFolder.setupNames + [SyncFolder.stampName] {
            try discard(target.appendingPathComponent(name), trash)
        }
        for name in SyncFolder.setupNames {
            let from = source.appendingPathComponent(name)
            guard files.fileExists(atPath: from.path) else { continue }
            do {
                try files.copyItem(
                    at: from,
                    to: target.appendingPathComponent(name)
                )
            } catch {
                onLog("sync: could not copy \(name): \(error)")
                throw .copy(.couldNotWrite(name: name))
            }
        }
    }

    /// Moves `url` to the Trash, deleting it where the Trash
    /// refuses — a surviving file would make the replace a merge.
    func discard(
        _ url: URL,
        _ trash: (URL) throws -> Void
    ) throws(SyncRefusal) {
        let files = FileManager.default
        guard files.fileExists(atPath: url.path) else { return }
        do {
            try trash(url)
        } catch {
            do {
                try files.removeItem(at: url)
            } catch {
                onLog(
                    "sync: could not remove "
                        + "\(url.lastPathComponent): \(error)"
                )
                throw .copy(.couldNotWrite(name: url.lastPathComponent))
            }
        }
    }
}
