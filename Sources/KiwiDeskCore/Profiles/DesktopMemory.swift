import Foundation

/// Per-display native Desktop bookkeeping for Space switching (#888).
@MainActor
final class DesktopMemory {
    /// Remembered Space ID per native Desktop number and display UUID.
    var virtualSpaces: [String: [Int: SpaceID]] = [:]

    /// The window each Desktop had focused when the user left it,
    /// keyed like `virtualSpaces` (#1207) — written BEFORE the
    /// departure fold walks `Space.focused` down the gone windows.
    var focusedWindows: [String: [Int: WindowID]] = [:]

    /// The focus a Desktop return owes its remembered window,
    /// paid at that window's ARRIVAL (#1207) — the #1007 shape,
    /// a second instance: per-window record, bound, rekey.
    let returnFocus = FollowFocusIntent()

    /// Last observed native Space ID per display (`KiwiCore+BootSeams`,
    /// docs/cli.md).
    var lastDisplaySpaces: [String: SkyLight.SpaceID] = [:]

    /// Seeds display space readings from desktop snapshot at boot.
    func seed(_ snapshot: DesktopSnapshot) {
        lastDisplaySpaces = snapshot.currentSpaces
    }
}
