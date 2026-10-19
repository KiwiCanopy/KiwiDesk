import Foundation

/// The setup a sync folder holds, read as files (#2324 slice 2).
///
/// A sync folder carries the same files the config folder does —
/// those `ConfigArtifact` says travel, plus `init.lua` — and one
/// stamp naming the Mac that last copied into it. This Mac's own
/// files (`MachineLocation`'s) never reach it.
public enum SyncFolder {
    /// The setup's names inside a folder: every artifact a backup
    /// carries that lives in the config folder, plus `init.lua`.
    /// Read off the register, so a new travelling store syncs too.
    static let setupNames: [String] =
        ConfigArtifact.allCases.filter(\.syncs).map(name(of:)) + [initLua]

    /// `init.lua`, which carries no format and is no artifact.
    static let initLua = "init.lua"

    /// The stamp a copy into the folder writes.
    static let stampName = name(of: .syncStamp)

    static func name(of artifact: ConfigArtifact) -> String {
        artifact.fileName ?? "profiles"
    }

    /// One side of the comparison, read off its files' dates.
    static func side(
        in directory: URL,
        mac: String?
    ) -> SyncSide {
        let files = FileManager.default
        var newest: Date?
        for name in setupNames {
            let url = directory.appendingPathComponent(name)
            for file in [url] + contents(of: url) {
                guard
                    let date = try? file.resourceValues(
                        forKeys: [.contentModificationDateKey]
                    ).contentModificationDate,
                    files.fileExists(atPath: file.path)
                else { continue }
                newest = max(newest ?? date, date)
            }
        }
        let profiles = contents(
            of: directory.appendingPathComponent(name(of: .profiles))
        ).filter { $0.pathExtension == "json" }
        return SyncSide(
            lastChanged: newest,
            mac: newest == nil ? nil : mac,
            profileCount: profiles.count
        )
    }

    /// The first store in `directory` a newer KiwiDesk wrote.
    static func newerFormat(in directory: URL) -> NewerFormatOnDisk? {
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwidesk-sync-probe")
        let gui = GuiConfigStore(directory: directory, machine: scratch)
        if let refusal = gui.sidecarNewerFormat()
            ?? PaletteStore(directory: directory).newerFormat()
            ?? LookStore(directory: directory).newerFormat()
        {
            return refusal
        }
        let profiles = directory.appendingPathComponent(
            name(of: .profiles)
        )
        return contents(of: profiles)
            .filter { $0.pathExtension == "json" }
            .lazy.compactMap { NewerFormatOnDisk.checkProfile($0) }
            .first
    }

    /// The Mac a folder's stamp names, if it carries one.
    static func stampedMac(in directory: URL) -> String? {
        let url = directory.appendingPathComponent(stampName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SyncStamp.self, from: data).mac
    }

    static func contents(of url: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
    }
}

/// The stamp a copy writes into the folder: the Mac it came from.
struct SyncStamp: Codable, Equatable {
    var format = 1
    let mac: String
}

/// One side of a Compare and Copy: when its setup last changed,
/// on which Mac, and how many profiles it holds.
public struct SyncSide: Equatable, Sendable {
    /// The newest change to any of the side's setup files; nil
    /// where the side holds no setup at all.
    public let lastChanged: Date?
    /// The Mac that made it, where known.
    public let mac: String?
    public let profileCount: Int

    public init(lastChanged: Date?, mac: String?, profileCount: Int) {
        self.lastChanged = lastChanged
        self.mac = mac
        self.profileCount = profileCount
    }

    /// Whether the side holds no setup.
    public var isEmpty: Bool { lastChanged == nil }
}

/// Why a copy cannot run, as structure (#96): the GUI narrates it.
public enum SyncRefusal: Error, Equatable, Sendable {
    /// The folder is gone, renamed or unreadable.
    case folderUnavailable
    /// The folder is in iCloud Drive, which is off on this Mac.
    case iCloudDriveOff
    /// The folder is KiwiDesk's own config folder, or holds it, or
    /// sits inside it.
    case sameFolder
    /// A newer KiwiDesk wrote a store in the folder (ruling 2).
    case folderNewer(NewerFormatOnDisk)
    /// The folder holds no setup to take.
    case folderEmpty
    /// The folder's setup cannot be read whole — a profile that
    /// will not decode, or profiles with no settings to go with.
    case folderUnreadable
    /// A newer KiwiDesk wrote a store on this Mac (#2324 slice 1c).
    case thisMacNewer(NewerFormatOnDisk)
    /// The copy itself failed; `SetupBundleError` names how.
    case copy(SetupBundleError)
}

/// What Compare and Copy shows: both sides, and what refuses each
/// direction.
public struct SyncComparison: Equatable, Sendable {
    public let thisMac: SyncSide
    public let folder: SyncSide
    /// Why Keep This Mac's cannot run, if it cannot.
    public let keepThisMacRefusal: SyncRefusal?
    /// Why Keep the Folder's cannot run, if it cannot.
    public let keepFolderRefusal: SyncRefusal?
}
