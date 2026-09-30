import Foundation

/// An edit of the settings a write applies (#1518).
public typealias SettingsEdit = (inout TilingSettings) -> Void

/// What the GUI takes when the live profile is written from outside
/// Settings: the edit, and whether a profile's file took it.
public typealias LiveProfileWrite =
    @MainActor (LiveProfileEdit, _ persisted: Bool) -> Void

/// The one door a write of the live profile from outside Settings
/// takes — the tour's look (#1720), a bar menu's row (#1518), and a
/// Space added to or removed from the profile (#1790): the bar's
/// Delete, `create_space`/`delete_space` with `profile`, and
/// Settings ▸ Spaces' add button. The draft policy that answers it
/// is profiles.md's.
extension KiwiCore {
    /// `edit` lands in the live profile's file, non-adopting, then
    /// reaches an open draft through `onLiveProfileWritten`, which
    /// is told whether a file took it: with no profile live, or a
    /// write that failed, the change lasts the session. Live state
    /// is the caller's. Returns whether a file took it.
    @discardableResult
    func writeThroughLiveProfile(_ edit: LiveProfileEdit) -> Bool {
        let persisted =
            profiles.currentName.map { writeStoredProfile($0, edit) }
            ?? false
        onLiveProfileWritten(edit, persisted)
        return persisted
    }

    /// Non-adopting, like `overwriteProfile`: `current` and
    /// `dirty` stay as they were, and `redeclare` keeps the
    /// adoption record in step with the file this door wrote.
    private func writeStoredProfile(
        _ name: String,
        _ edit: LiveProfileEdit
    ) -> Bool {
        do {
            var profile = try profiles.read(name: name)
            profile.apply(edit, monitors: liveFingerprints)
            try profiles.write(profile)
            // Only a Space edit moves what is declared; a settings
            // edit leaves that to the next apply (#1245).
            if case .settings = edit {
            } else {
                profiles.redeclare(profile)
            }
            // A follower's look is the shared one (#1752); an edit
            // that leaves the look alone lands nothing.
            recordLookWrite(of: profile)
            refreshConfigIssues()
            return true
        } catch {
            onLog("live profile \(name) not written: \(error)")
            return false
        }
    }
}
