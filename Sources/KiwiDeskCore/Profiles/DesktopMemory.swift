import Foundation

/// Per-display native Desktop bookkeeping for Space switching (#888).
@MainActor
final class DesktopMemory {
    /// Remembered Space ID per native Desktop number and display UUID.
    var virtualSpaces: [String: [Int: SpaceID]] = [:]

    /// Each space's last honored focus per native Space it was
    /// honored ON (#1207) — written at the focus report, never by
    /// a fold or the switch handler.
    var honoredFocus: [SpaceID: [SkyLight.SpaceID: WindowID]] = [:]

    /// The focus a Desktop return owes its remembered window,
    /// paid at that window's ARRIVAL (#1207) — the #1007 shape,
    /// a second instance: per-window record, bound, rekey.
    let returnFocus = FollowFocusIntent()

    /// Desktops whose stamp write was dispatched and not yet
    /// confirmed by a later snapshot (#1147). Written by
    /// `stampedDesktopSnapshot` alone; the deferred verify is
    /// argued there.
    var stampAttempts: Set<SkyLight.SpaceID> = []

    /// Desktops that did not keep a stamp this process. One
    /// attempt each: a write the WindowServer dropped is not
    /// retried in a loop, and every consumer falls back to the
    /// Mission Control number for them.
    var unstampable: Set<SkyLight.SpaceID> = []

    /// Last observed native Space ID per display (`KiwiCore+BootSeams`,
    /// docs/cli.md).
    var lastDisplaySpaces: [String: SkyLight.SpaceID] = [:]

    /// The per-Desktop census (#1146) against the caller's one
    /// topology reading — live by default, replaced by a test;
    /// the one door production reads it through
    /// (`DesktopCensusSeamTests`).
    var readCensus: @MainActor ([NativeSpace]) -> DesktopCensus? =
        NativeSpaces.desktopCensus(spaces:)

    /// The compositor's word on ONE window at its destroy
    /// (#1146) — the gone classifier's read, live by default and
    /// pinned to `.unavailable` by `makeTestCore`, since a
    /// fixture id can be a real window on the host.
    var readWindowSpace: @MainActor (WindowID) -> WindowSpaceReading =
        NativeSpaces.windowSpaceReading(of:)

    /// Seeds display space readings from desktop snapshot at boot.
    func seed(_ snapshot: DesktopSnapshot) {
        lastDisplaySpaces = snapshot.currentSpaces
    }
}
