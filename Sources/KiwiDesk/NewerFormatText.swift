import KiwiDeskCore
import SwiftUI

/// The one renderer of the newer-format latch (#2324 ruling 2,
/// #96): Core hands over `NewerFormatOnDisk` or the issue kind,
/// and these are its sentences.
enum NewerFormatText {
    /// A store's Config Issue, under its file name.
    @MainActor
    static var issue: String {
        L(
            "config_issues.newer_format",
            "Saved by a newer KiwiDesk, so this version can't read "
                + "it and leaves it unchanged. Update KiwiDesk to "
                + "keep syncing."
        )
    }

    /// A profile row's cause, which also says why it has no
    /// Delete.
    @MainActor
    static var profile: String {
        L(
            "profiles.broken.newer_format",
            "Saved by a newer KiwiDesk, so this version can't open "
                + "it and won't delete it. Update KiwiDesk to keep "
                + "syncing."
        )
    }

    /// Why Settings' Save is greyed.
    @MainActor
    static func saveBlocked(_ latch: NewerFormatOnDisk) -> String {
        L(
            "settings.save_blocked_newer_format",
            "A newer KiwiDesk saved %1$@, so this version won't "
                + "overwrite it. Update KiwiDesk to keep syncing.",
            latch.fileName
        )
    }

    /// A failed write's detail for a "… failed: %1$@" frame: the
    /// refusal's sentence, else the error as the log has it.
    @MainActor
    static func detail(_ error: Error) -> String {
        guard let refusal = error as? NewerFormatOnDisk else {
            return "\(error)"
        }
        return L(
            "settings.write_refused_newer_format",
            "A newer KiwiDesk saved %1$@, so this version left it "
                + "unchanged. Update KiwiDesk to keep syncing.",
            refusal.fileName
        )
    }
}
