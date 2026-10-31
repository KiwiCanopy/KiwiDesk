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
    /// Whether this session has read the stored memory — the load
    /// adopting it, or the discard clearing it (#2324). A memory
    /// established by a departure alone is NOT adopted: written,
    /// it would replace every Desktop the session did not visit.
    var spaceMemoryAdopted = false

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

    /// The last honored focus per native Desktop, any Space (#1564)
    /// — filed beside `honoredFocus`, read at the departure.
    var lastHonoredOn: [SkyLight.SpaceID: WindowID] = [:]
    /// The carried sticky window each Desktop was LEFT with
    /// (#1564), filed at the departure and taken at the return.
    var stickyLeft: [SkyLight.SpaceID: WindowID] = [:]
    /// The focus a return owes that window, and when it was owed,
    /// paid at the settle.
    var stickyReturn: (window: WindowID, at: ContinuousClock.Instant)?

    /// The focus a Desktop return owes its remembered window,
    /// paid at that window's ARRIVAL (#1207) — the #1007 shape,
    /// a second instance: per-window record, bound, rekey.
    let returnFocus = FollowFocusIntent()
    /// When each window LEFT WITH ITS DESKTOP (#1364): filed
    /// through `fileSwitchDeparture`, read against the switch's
    /// own time by `departedWithThisSwitch`, age-bounded, and
    /// re-keyed and retired with `honoredFocus`.
    var switchDepartures: [WindowID: Date] = [:]

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

    /// The two marks a build before #2324 kept in this Mac's
    /// defaults, read by the top-ups and carried into `gui.json`
    /// once (`crossLegacyShortcutOffer`); nil where neither is set.
    /// Pinned by both `makeTestCore` twins.
    var readLegacyShortcutOffer: @MainActor () -> ShortcutOffer? = {
        let defaults = UserDefaults.standard
        let keys = [shortcutMarkKey, defaultsGenerationKey]
        guard keys.contains(where: { defaults.object(forKey: $0) != nil })
        else { return nil }
        return ShortcutOffer(
            desktop: defaults.integer(forKey: shortcutMarkKey),
            generation: defaults.integer(forKey: defaultsGenerationKey)
        )
    }
    var clearLegacyShortcutOffer: @MainActor () -> Void = {
        UserDefaults.standard.removeObject(forKey: shortcutMarkKey)
        UserDefaults.standard.removeObject(forKey: defaultsGenerationKey)
    }
    nonisolated static let shortcutMarkKey = "desktopShortcutMark"
    nonisolated static let defaultsGenerationKey =
        "defaultShortcutsGeneration"
    /// The offer the top-ups last read or wrote this session, so a
    /// Desktop switch with nothing new to offer reads no file.
    var knownShortcutOffer: ShortcutOffer?
    /// The highest Desktop a declining setup (Lua-owned, no
    /// sidecar) was asked about this session, so a switch does not
    /// ask again.
    var shortcutTopUpDeclined = 0

    /// The apps a `gather` moved windows of from other Desktops,
    /// drained by its one reap (#1510).
    var gatherReapPIDs: Set<pid_t> = []

    /// Away windows WindowServer reported destroyed, awaiting the
    /// compositor's per-window check (#2660).
    var awayDestroyed: Set<WindowID> = []

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

    /// The native Space each screen shows, filed at the HEAD of
    /// every Desktop switch so the switch's own rings read it
    /// (#2149); `lastDisplaySpaces` is filed at the tail (#1215).
    var shownSpaces: [String: SkyLight.SpaceID] = [:]
    /// Whether each screen's shown Space is a user Space, filed
    /// from every Desktop reading taken where the shown Space can
    /// change and dropped at a display change; the shelf's
    /// stand-down reads it rather than two WindowServer round
    /// trips per pass (#2667).
    var shownUserSpaces: [String: Bool] = [:]

    /// Files the native Space each screen shows from `snapshot`.
    func fileShown(_ snapshot: DesktopSnapshot) {
        shownSpaces = snapshot.currentSpaces
        fileShownUserSpaces(snapshot)
    }

    /// Files only the verdict, for a reading that must leave
    /// `shownSpaces` to the switch handler (#1215).
    func fileShownUserSpaces(_ snapshot: DesktopSnapshot) {
        shownUserSpaces = snapshot.currentSpacesAreUser
    }

    /// Seeds display space readings from desktop snapshot at boot.
    func seed(_ snapshot: DesktopSnapshot) {
        lastDisplaySpaces = snapshot.currentSpaces
        fileShown(snapshot)
    }
}
