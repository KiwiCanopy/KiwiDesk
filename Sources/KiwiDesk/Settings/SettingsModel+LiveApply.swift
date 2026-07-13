import Foundation
import KiwiDeskCore

/// The transient feedback a recorder row shows after a
/// live-applied edit (#123): the recorded shortcut is either
/// active, or the system declined to register it (a reserved
/// combo) — live-apply makes that failure observable at
/// record time instead of after a Save.
enum LiveApplyStatus {
    case applied
    case denied
}

/// Identity-carrying wrapper so re-recording the same row
/// re-triggers the caption's fade timer (`onChange` fires on
/// the fresh `id` even when the status repeats).
struct LiveApplyFeedback: Equatable {
    let status: LiveApplyStatus
    let id = UUID()
}

/// Live-apply for keybinding edits (#123 Part 1, live target
/// only): a successfully committed recording re-registers the
/// Carbon hotkeys immediately, without writing profile JSON.
/// `isDirty` and the footer keep their exact meaning ("the
/// file hasn't caught up"); Save still persists, and Revert /
/// discard re-applies the reverted bindings live (see
/// `reload()`).
///
/// Stored-profile edits (`target != .live`) stay fully staged:
/// instant apply would silently rewrite the RUNNING hotkeys
/// while the banner says an inactive profile is being edited.
extension SettingsModel {
    /// Applies the edited mode set to the running hotkeys and
    /// returns the row's feedback caption. `combo` is the
    /// just-recorded combo, or nil for a clear (re-registers,
    /// no caption). Returns nil when the edit stays staged
    /// (stored-profile target) — the recorder shows nothing.
    func liveApplyRecorded(
        _ combo: String?
    ) -> LiveApplyFeedback? {
        guard target == .live else { return nil }
        core.liveApplyKeybindings(modes: config.modes)
        liveKeysApplied = true
        guard let combo, let parsed = KeyCombo.parse(combo)
        else { return nil }
        let denied = core.keys.activationFailures
            .contains(parsed)
        return LiveApplyFeedback(
            status: denied ? .denied : .applied
        )
    }
}
