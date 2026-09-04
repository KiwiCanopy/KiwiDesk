import Foundation

/// Per-Desktop bookkeeping for Space switching (#888) and for
/// the identity each Desktop is filed under (#1147) — the Space
/// memory, the focus a return owes, the compositor seams the away
/// ledger reads through, and the stamp write with its one-attempt
/// ledger.
@MainActor
final class DesktopMemory {
    /// The Space each Desktop was last showing, keyed by the
    /// Desktop itself (#1147). It was keyed by (main display
    /// UUID, Mission Control number) until a `DesktopKey` could
    /// name the Desktop: the partition existed because a number
    /// means nothing without saying whose numbering it is, and
    /// an identity means the same thing on every arrangement.
    var virtualSpaces: [DesktopKey: SpaceID] = [:]

    /// Whether the map above is the session's own answer yet
    /// (#1230). It becomes durable through `gui.json`, and every
    /// sidecar write stamps it in — so a write taken BEFORE the
    /// config has been read would erase the file's copy with an
    /// empty map that means "nothing established", not "nothing
    /// remembered". Set by the load, by the first departure
    /// filed, and by the discard, which is a cleared memory
    /// rather than an absent one.
    var spaceMemoryEstablished = false

    /// The Desktop the last switch arrived on, by its NATIVE id
    /// (#1230) — the same Desktop `KiwiCore.lastDesktop` names by
    /// key. A key is re-keyed at any mint, so anything outliving
    /// one reading compares on this: the 600 ms settle's pending
    /// closure would otherwise stand the whole settle down once
    /// its Desktop was stamped.
    var lastDesktopSpace: SkyLight.SpaceID?

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

    /// The stamp write (#1147) — live by default and the one
    /// door production writes through, so a test never reaches
    /// the host's real Desktops with a fixture space id. Returns
    /// whether the write was DISPATCHED; whether it landed is
    /// the next snapshot's verdict.
    var writeStamp: @MainActor (SkyLight.SpaceID, DesktopIdentity) -> Bool =
        KiwiCore.liveStampWrite

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
