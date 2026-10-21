import Foundation
import KiwiDeskCore

/// The sentences Sync across Macs speaks (#2324 slice 2): Core
/// names the refusal, this narrates it (#96).
@MainActor
enum SyncText {
    static var label: String {
        L("general.sync", "Sync across Macs")
    }

    /// The row's label under the heading: what the pop-up picks.
    static var folderLabel: String {
        L("general.sync.folder_label", "Folder")
    }

    static var help: String {
        L(
            "general.sync.help",
            "Copies your settings, profiles, color palettes, looks "
                + "and init.lua between this Mac and a folder your "
                + "sync app shares with your other Macs. Nothing is "
                + "merged; the setup that gets replaced goes to the "
                + "Trash."
        )
    }

    static var none: String { L("general.sync.none", "None") }

    static var iCloudDrive: String {
        L("general.sync.icloud", "iCloud Drive")
    }

    static var chooseFolder: String {
        L("general.sync.folder", "Folder…")
    }

    static var compare: String {
        L("general.sync.compare", "Compare and Copy…")
    }

    /// The button's label without its ellipsis, for a sentence.
    static var compareName: String {
        compare.hasSuffix("…") ? String(compare.dropLast()) : compare
    }

    static var noFolderCaption: String {
        L(
            "general.sync.caption.none",
            "Choose a folder that iCloud Drive or another sync app "
                + "keeps up to date."
        )
    }

    static func chosenCaption(_ path: String) -> String {
        L(
            "general.sync.caption.chosen",
            "%1$@ · Copies only when you choose %2$@.",
            path,
            compareName
        )
    }

    static var iCloudOff: String {
        L(
            "general.sync.caption.icloud_off",
            "iCloud Drive is turned off on this Mac."
        )
    }

    /// Why the row's folder refuses, drawn as its caption.
    static func caption(for refusal: SyncRefusal) -> String {
        switch refusal {
        case .folderUnavailable:
            return L(
                "general.sync.caption.missing",
                "Can't find this folder. It may have been moved, "
                    + "renamed or deleted."
            )
        case .iCloudDriveOff:
            return iCloudOff
        case .sameFolder:
            return L(
                "general.sync.caption.same",
                "That folder holds KiwiDesk's own settings, or sits "
                    + "inside them. Choose another one."
            )
        case .folderNewer:
            return L(
                "general.sync.caption.newer",
                "A newer KiwiDesk wrote this folder. Update to keep "
                    + "syncing."
            )
        default:
            return sentence(for: refusal)
        }
    }

    /// A refusal or a failed copy, as one sentence.
    static func sentence(for refusal: SyncRefusal) -> String {
        switch refusal {
        case .folderUnavailable, .iCloudDriveOff, .sameFolder,
            .folderNewer:
            return caption(for: refusal)
        case .folderUnreadable:
            return L(
                "general.sync.refusal.unreadable_folder",
                "KiwiDesk couldn't read the setup in the folder."
            )
        case .folderEmpty:
            return L(
                "general.sync.refusal.empty",
                "There's no setup in the folder yet."
            )
        case .thisMacNewer:
            return L(
                "general.sync.refusal.this_mac_newer",
                "A newer KiwiDesk wrote this Mac's settings, so "
                    + "they can't be replaced here. Update to keep "
                    + "syncing."
            )
        case .copy(let error):
            return sentence(for: error)
        }
    }

    private static func sentence(for error: SetupBundleError) -> String {
        switch error {
        case .luaOwnsThisMac:
            return L(
                "general.sync.refusal.lua_owned",
                "This Mac's settings come from your init.lua, so the "
                    + "folder's settings can't be applied here."
            )
        case .unreadableSettings, .unreadablePalettes, .unreadableLooks,
            .unreadableInitLua, .newerSettings:
            return L(
                "general.sync.refusal.unreadable_here",
                "KiwiDesk can't read some of this Mac's settings, so "
                    + "they can't be copied. Fix or reset the "
                    + "configuration first."
            )
        case .unreadable, .notABackup, .newerFormat, .empty:
            return sentence(for: .folderUnreadable)
        case .couldNotWrite:
            return SetupBackupText.sentence(for: error)
        }
    }

    static var failedTitle: String {
        L("general.sync.failed_title", "Couldn't Copy the Setup")
    }

    // MARK: - The sheet

    static var title: String {
        L("general.sync.sheet.title", "Which Setup Do You Want to Keep?")
    }

    static var body: String {
        L(
            "general.sync.sheet.body",
            "The one you keep is copied over the other. Nothing is "
                + "merged."
        )
    }

    static var thisMac: String { L("general.sync.this_mac", "This Mac") }

    static var includes: String {
        L(
            "general.sync.sheet.includes",
            "Settings, profiles, color palettes, looks and init.lua "
                + "are copied together."
        )
    }

    static var trashNote: String {
        L(
            "general.sync.sheet.trash",
            "The setup that gets replaced goes to the Trash."
        )
    }

    static var replacesEdits: String {
        L(
            "general.sync.sheet.replaces_edits",
            "Copying the folder's setup replaces the edits you "
                + "haven't saved."
        )
    }

    /// Where a side lies: "In ~ ▸ .config".
    static func inLocation(_ path: String) -> String {
        L("general.sync.sheet.in", "In %1$@", path)
    }

    // MARK: - The empty folder's alert

    static func firstCopyTitle(_ folder: String) -> String {
        L(
            "general.sync.first_copy.title",
            "Copy This Mac's Setup to “%1$@”?",
            folder
        )
    }

    static var firstCopyMessage: String {
        L(
            "general.sync.first_copy.message",
            "The folder doesn't hold a KiwiDesk setup yet. Settings, "
                + "profiles, color palettes, looks and init.lua are "
                + "copied."
        )
    }

    static var copyToFolder: String {
        L("general.sync.first_copy.copy", "Copy to Folder")
    }

    static var saveAndCopyToFolder: String {
        L("general.sync.first_copy.save_and_copy", "Save and Copy to Folder")
    }

    static var ok: String { L("general.sync.ok", "OK") }

    static var nothingHere: String {
        L("general.sync.sheet.empty", "Nothing here yet")
    }

    static var newerLine: String {
        L("general.sync.sheet.newer", "Written by a newer KiwiDesk")
    }

    static var newerTag: String { L("general.sync.sheet.newer_tag", "Newer") }

    static func changed(_ date: Date) -> String {
        L("general.sync.sheet.changed", "Changed %1$@", format(date))
    }

    /// The date alone, for the row whose glyph says "Changed".
    static func date(_ date: Date) -> String { format(date) }

    static func on(_ mac: String) -> String {
        L("general.sync.sheet.on", "On %1$@", mac)
    }

    static func profiles(_ count: Int) -> String {
        L("general.sync.sheet.profiles", "Profiles: %1$d", count)
    }

    static var keepThisMac: String {
        L("general.sync.keep_this_mac", "Keep This Mac's")
    }

    static var saveAndKeepThisMac: String {
        L("general.sync.save_and_keep", "Save and Keep This Mac's")
    }

    static var keepFolder: String {
        L("general.sync.keep_folder", "Keep the Folder's")
    }

    static var keepThisMacHint: String {
        L(
            "general.sync.keep_this_mac.hint",
            "Copies this Mac's setup to the folder. The folder's "
                + "goes to the Trash."
        )
    }

    static var keepFolderHint: String {
        L(
            "general.sync.keep_folder.hint",
            "Copies the folder's setup to this Mac. This Mac's goes "
                + "to the Trash."
        )
    }

    static var cancel: String { L("spaces.delete_confirm.cancel", "Cancel") }

    /// "Today at 14:02", in this Mac's locale.
    private static func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        // The language KiwiDesk speaks, not the system's.
        if let code = LocalizationManager.shared.selection {
            formatter.locale = Locale(identifier: code)
        }
        formatter.formattingContext = .middleOfSentence
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
