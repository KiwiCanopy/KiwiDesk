import Foundation
import SystemConfiguration

/// Compare and Copy (#2324 slice 2): one whole setup copied between
/// the config folder and a sync folder, in the direction the user
/// picks. The side being replaced goes to the Trash; nothing merges.
///
/// The folder is whatever the user's sync app keeps up to date, so
/// KiwiDesk writes it only in Keep This Mac's, and no read of the
/// folder migrates or rewrites a file in it.
extension KiwiCore {
    /// Both sides of `folder`'s comparison, and what refuses each
    /// direction. Reads the folder only; reading this Mac's stores
    /// may migrate them, as every load does.
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
    /// Mac's, the folder's going to `trash`, then stamps this Mac's
    /// name. Changes nothing on this Mac.
    ///
    /// Copies land in a staging folder inside `folder` first, so a
    /// copy that fails leaves the folder as it was; only then is
    /// each item swapped in. `trash` has no default.
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

    /// Why `folder` refuses both directions, if it does.
    public func syncFolderRefusal(_ folder: URL) -> SyncRefusal? {
        if SyncFolderLocation.isInICloudDrive(folder),
            !SyncFolderLocation.iCloudDriveIsOn
        {
            return .iCloudDriveOff
        }
        var isDirectory: ObjCBool = false
        guard
            FileManager.default.fileExists(
                atPath: folder.path,
                isDirectory: &isDirectory
            ), isDirectory.boolValue
        else { return .folderUnavailable }
        if Self.nests(folder, configDirectory) { return .sameFolder }
        return SyncFolder.newerFormat(in: folder).map {
            .folderNewer($0)
        }
    }

    /// Whether either folder is the other or lies inside it, which
    /// would make a copy trash files it reads or recurse.
    static func nests(_ one: URL, _ other: URL) -> Bool {
        let a = one.resolvingSymlinksInPath().standardizedFileURL.path
        let b = other.resolvingSymlinksInPath().standardizedFileURL.path
        return a == b || a.hasPrefix(b + "/") || b.hasPrefix(a + "/")
    }

    /// A newer store on this Mac, which a Keep the Folder's would
    /// replace and Keep This Mac's could not read (slice 1c).
    func thisMacNewer() -> NewerFormatOnDisk? {
        guiConfigWriteLatch()
            ?? paletteLibrary.newerFormat()
            ?? lookLibrary.newerFormat()
    }

    /// The export's own refusals (#606): a file this Mac cannot
    /// read would travel as a setup nobody can open.
    func keepThisMacRefusal(_ folder: URL) -> SyncRefusal? {
        if let refusal = syncFolderRefusal(folder) { return refusal }
        if let newer = thisMacNewer() { return .thisMacNewer(newer) }
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

    /// Why Keep the Folder's cannot run, judged before anything on
    /// this Mac is touched.
    public func keepFolderRefusal(_ folder: URL) -> SyncRefusal? {
        keepFolderRefusal(folder, SyncFolder.side(in: folder, mac: nil))
    }

    func keepFolderRefusal(
        _ folder: URL,
        _ side: SyncSide
    ) -> SyncRefusal? {
        if let refusal = refusalBeforeReading(folder, side) {
            return refusal
        }
        return folderIsWhole(folder) ? nil : .folderUnreadable
    }

    /// Keep the Folder's refusals that need no read of the setup.
    func refusalBeforeReading(
        _ folder: URL,
        _ side: SyncSide
    ) -> SyncRefusal? {
        if let refusal = syncFolderRefusal(folder) { return refusal }
        if side.isEmpty { return .folderEmpty }
        if let newer = thisMacNewer() { return .thisMacNewer(newer) }
        return nil
    }

    // MARK: - Files

    /// Copies `source`'s setup into a staging folder inside
    /// `target`, then swaps each item in, the one it replaces going
    /// to `trash`, and trashes what `source` does not hold. A copy
    /// that fails refuses before `target` is touched.
    func replaceSetupFiles(
        in target: URL,
        from source: URL,
        trash: (URL) throws -> Void
    ) throws(SyncRefusal) {
        let files = FileManager.default
        // A stage a crash left behind would otherwise sync forever.
        for stale in SyncFolder.contents(of: target)
        where stale.lastPathComponent.hasPrefix(Self.incomingPrefix) {
            try? files.removeItem(at: stale)
        }
        let stage = target.appendingPathComponent(
            Self.incomingPrefix + UUID().uuidString
        )
        defer { try? files.removeItem(at: stage) }
        var incoming: [String] = []
        do {
            try files.createDirectory(
                at: stage,
                withIntermediateDirectories: true
            )
            for name in SyncFolder.setupNames {
                let from = source.appendingPathComponent(name)
                guard files.fileExists(atPath: from.path) else {
                    continue
                }
                try files.copyItem(
                    at: from,
                    to: stage.appendingPathComponent(name)
                )
                incoming.append(name)
            }
        } catch {
            onLog("sync: could not stage the copy: \(error)")
            throw .copy(.couldNotWrite(name: target.lastPathComponent))
        }
        // The old stamp goes first, so a swap failing partway never
        // leaves a mixed folder named after the other Mac.
        try discard(target.appendingPathComponent(SyncFolder.stampName), trash)
        for name in SyncFolder.setupNames {
            let into = target.appendingPathComponent(name)
            try discard(into, trash)
            guard incoming.contains(name) else { continue }
            do {
                try files.moveItem(
                    at: stage.appendingPathComponent(name),
                    to: into
                )
            } catch {
                onLog("sync: could not move \(name) in: \(error)")
                throw .copy(.couldNotWrite(name: name))
            }
        }
    }

    static let incomingPrefix = ".kiwidesk-incoming-"

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
