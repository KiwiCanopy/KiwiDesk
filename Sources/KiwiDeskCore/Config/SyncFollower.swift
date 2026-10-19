import Foundation

/// Where keeping a sync folder in step stands (#2324 slice 3), as
/// structure the GUI narrates (#96).
public enum SyncStatus: Equatable, Sendable {
    /// Not following a folder.
    case off
    /// This Mac and the folder hold the same setup.
    case upToDate
    /// The folder is missing, iCloud Drive is off, or iCloud has
    /// not downloaded a file yet.
    case folderUnavailable
    /// Both sides changed since they last matched: Compare and
    /// Copy settles which one stays.
    case changedOnBoth
    /// A sync app left a conflict copy beside the setup; its path
    /// below the folder.
    case conflictCopy(String)
    /// A newer KiwiDesk wrote a file on the other side (ruling 2).
    case newerOnAnotherMac(NewerFormatOnDisk)
}

/// A change the sync folder brought in (#2324 ruling 4), handed to
/// Settings through `SyncFollower.onSyncedIn`.
public struct SyncedChange: Equatable, Sendable {
    /// The paths that came in, below the setup's root.
    public let paths: [String]
    /// The Mac the folder's stamp names, where it names one.
    public let mac: String?

    /// Whether `init.lua` came in.
    public var touchesInitLua: Bool { paths.contains(SyncFolder.initLua) }
}

/// The state of following a sync folder (#2324 slice 3), held by
/// `KiwiCore.sync`; the pass itself is `KiwiCore+SyncFollow`.
@MainActor
public final class SyncFollower {
    /// The folder followed, nil while none is.
    public internal(set) var folder: URL?
    public internal(set) var status: SyncStatus = .off {
        didSet {
            if status != oldValue { onStatusChange(status) }
        }
    }
    public var onStatusChange: @MainActor (SyncStatus) -> Void = { _ in }
    /// A pass brought changes in and the config reloaded.
    public var onSyncedIn: @MainActor (SyncedChange) -> Void = { _ in }

    /// The folder the app's defaults say to follow, read when boot
    /// is ready; pinned to none by both `makeTestCore` twins.
    var storedFolder: @MainActor () -> URL? = {
        SyncFolderLocation.followed(in: .standard)
    }
    /// Starts the live folder watch; pinned inert by both
    /// `makeTestCore` twins, whose suites run the pass directly.
    var makeWatch:
        @MainActor ([URL], @escaping @MainActor () -> Void) -> SyncWatching? =
            SyncWatch.live
    /// Where a removed file goes; pinned to a delete by both twins,
    /// so no suite fills the developer's Trash.
    var trash: (URL) throws -> Void = KiwiCore.moveToTrash
    /// How long the watch waits for quiet before a pass.
    var quietDelay: TimeInterval = 1

    var watch: SyncWatching?
    var pending: DispatchWorkItem?
    /// Above zero while a Compare and Copy rewrites either side.
    var paused = 0
    /// Above zero inside the door a pulled change enters by: no
    /// machine event writes a synced file there (#2324).
    var adopting = 0

    init() {}
}
