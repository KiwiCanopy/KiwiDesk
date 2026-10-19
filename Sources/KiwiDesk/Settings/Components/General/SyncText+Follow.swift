import Foundation
import KiwiDeskCore

/// The words for following a sync folder (#2324 slice 3): the
/// switch, the status line under it, the strip a change from
/// another Mac raises, and the question at Save.
extension SyncText {
    static var follow: String {
        L("general.sync.follow", "Keep in sync automatically")
    }

    /// The status line while following `folder` (its path, named
    /// the way the row names it).
    static func status(_ status: SyncStatus, folder: String) -> String {
        switch status {
        case .off, .upToDate:
            return L(
                "general.sync.status.up_to_date",
                "%1$@ · Up to date.",
                folder
            )
        case .folderUnavailable:
            return L(
                "general.sync.status.unavailable",
                "Can't reach the folder right now. Changes made on "
                    + "this Mac wait here until it's back."
            )
        case .changedOnBoth:
            return L(
                "general.sync.status.both",
                "This Mac and the folder both changed. Choose which "
                    + "setup to keep with %1$@.",
                compareName
            )
        case .conflictCopy(let name):
            return L(
                "general.sync.status.conflict_copy",
                "Your sync app left a conflict copy, %1$@. KiwiDesk "
                    + "doesn't use it; delete it once you've checked it.",
                name
            )
        case .newerOnAnotherMac:
            return L(
                "general.sync.status.newer",
                "A newer KiwiDesk on another Mac changed this setup. "
                    + "Update to keep syncing."
            )
        case .newerHere:
            return L(
                "general.sync.status.newer_here",
                "A newer KiwiDesk changed this Mac's setup. Update to "
                    + "keep syncing."
            )
        }
    }

    /// Whether `status` asks for the user's attention.
    static func warns(_ status: SyncStatus) -> Bool {
        switch status {
        case .off, .upToDate: return false
        default: return true
        }
    }

    /// The strip a change from another Mac raises over unsaved edits.
    static func arrived(on mac: String?) -> String {
        guard let mac else {
            return L(
                "general.sync.arrived.unnamed",
                "Your setup changed on another Mac. Saving keeps your "
                    + "edits on top of it."
            )
        }
        return L(
            "general.sync.arrived",
            "Your setup changed on %1$@. Saving keeps your edits on "
                + "top of it.",
            mac
        )
    }

    // MARK: - The question at Save

    static func conflictTitle(_ conflict: SyncConflict) -> String {
        guard let mac = conflict.mac else {
            return L(
                "general.sync.conflict.title_unnamed",
                "%1$@ Also Changed on Another Mac",
                conflict.label
            )
        }
        return L(
            "general.sync.conflict.title",
            "%1$@ Also Changed on %2$@",
            conflict.label,
            mac
        )
    }

    static func conflictMessage(_ conflict: SyncConflict) -> String {
        L(
            "general.sync.conflict.message",
            "Yours: %1$@\nTheirs: %2$@",
            conflict.yours,
            conflict.theirs
        )
    }

    static var keepYours: String {
        L("general.sync.conflict.keep_yours", "Keep Yours")
    }

    static var useTheirs: String {
        L("general.sync.conflict.use_theirs", "Use Theirs")
    }

    static var yourEdits: String {
        L("general.sync.conflict.your_edits", "your edits to the file")
    }

    static var theirEdits: String {
        L(
            "general.sync.conflict.their_edits",
            "the other Mac's edits to the file"
        )
    }
}
