import Foundation

/// An edit of the settings a write applies (#1518).
public typealias SettingsEdit = (inout TilingSettings) -> Void

/// What the GUI takes when the live profile is written from outside
/// Settings: the edit, and whether a profile's file took it.
public typealias LiveProfileWrite =
    @MainActor (@escaping SettingsEdit, _ persisted: Bool) -> Void

/// The one door a write of the live profile from outside Settings
/// takes — the tour's look (#1720), a bar menu's row (#1518). The
/// draft policy that answers it is profiles.md's.
extension KiwiCore {
    /// `edit` lands in the live profile's file, non-adopting, then
    /// reaches an open draft through `onLiveProfileWritten`, which
    /// is told whether a file took it: with no profile live, or a
    /// write that failed, the change lasts the session. Live
    /// settings are the caller's.
    func writeThroughLiveProfile(_ edit: @escaping SettingsEdit) {
        let persisted =
            profiles.currentName.map { writeStoredSettings($0, edit) }
            ?? false
        onLiveProfileWritten(edit, persisted)
    }

    /// Non-adopting, like `overwriteProfile`: `current` and
    /// `dirty` stay as they were.
    private func writeStoredSettings(
        _ name: String,
        _ edit: SettingsEdit
    ) -> Bool {
        do {
            var profile = try profiles.read(name: name)
            edit(&profile.settings)
            try profiles.write(profile)
            refreshConfigIssues()
            return true
        } catch {
            onLog("live profile \(name) not written: \(error)")
            return false
        }
    }
}
