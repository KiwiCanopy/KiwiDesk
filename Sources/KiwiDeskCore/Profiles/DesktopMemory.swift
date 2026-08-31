import Foundation

/// Per-display native Desktop bookkeeping for Space switching (#888).
@MainActor
final class DesktopMemory {
    /// Remembered Space ID per native Desktop number and display
    /// UUID. Keyed per display so a remembered Space never
    /// survives a change of WHICH screen is main: numbering under
    /// a different main is a different fact, and reading it back
    /// would activate a Space the user never left there.
    var virtualSpaces: [String: [Int: SpaceID]] = [:]

    /// Last observed native Space ID per display. SEEDED at boot
    /// (`KiwiCore+BootSeams`): left empty, the session's first
    /// switch diffs against nothing, reads every display as
    /// changed, and attributes a secondary swipe to `monitor: 1` —
    /// the field docs/cli.md tells subscribers to key
    /// profile-selection off (review 2026-08-18).
    var lastDisplaySpaces: [String: SkyLight.SpaceID] = [:]

    /// Seeds display space readings from desktop snapshot at boot.
    func seed(_ snapshot: DesktopSnapshot) {
        lastDisplaySpaces = snapshot.currentSpaces
    }
}
