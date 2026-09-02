import Foundation

/// Per-display native Desktop bookkeeping for Space switching (#888).
@MainActor
final class DesktopMemory {
    /// Remembered Space ID per native Desktop number and display UUID.
    var virtualSpaces: [String: [Int: SpaceID]] = [:]

    /// Each space's last HONORED focus per Desktop (#1207),
    /// written at every honored focus report and never by a fold:
    /// a Desktop departure's destroys can precede the switch
    /// handler, so a handler-time read sees `Space.focused`
    /// already walked. Two Desktops showing one space keep their
    /// own entries; a report that beat the handler is stamped
    /// with the Desktop being left and re-stamped at the arrival.
    var honoredFocus: [SpaceID: [Int: WindowID]] = [:]

    /// The most recent honored focus and when (#1207): a focus
    /// honored SINCE the last switch is macOS's own restore, which
    /// the return keeps rather than paying the memory over it.
    var lastHonored: (window: WindowID, at: Date)?

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
