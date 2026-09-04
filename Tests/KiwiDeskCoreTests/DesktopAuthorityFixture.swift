import CoreGraphics
import Foundation

@testable import KiwiDeskCore

// The #888 authority suites' shared fixture — the topology they
// pin and the override reset, in one file because the suites were
// split off a single one at the §2.1 ceiling and a divergent copy
// of `resetOverrides` would leave a process-global override set
// for whatever runs next (`.claude/rules/tests.md`: the
// divergence ground). No assertions live here.
//
// **Every suite built on this pins the whole machine surface.**
// A `handleDesktopChange` fixture reaches `CGMainDisplayID`,
// `CGDisplayCreateUUIDFromDisplayID` and SkyLight's per-display
// reads on top of the space topology, so `pinTwoDisplays()` sets
// all of them: a fixture that pinned only the spaces was
// deterministic by luck — unknown ids count as user (#670) — and
// would have started reading the developer's real desks the day
// that default changed (review, 2026-08-18).

@MainActor
func makeAuthorityCore() -> KiwiCore {
    makeTestCore(
        configDirectory: FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "kiwi-core-\(UUID().uuidString)"
            )
    )
}

@MainActor
func connectAuthority(_ core: KiwiCore, _ displays: [Display]) {
    for display in displays {
        core.state.workspaces.upsertDisplay(display)
    }
}

func authorityDisplay(
    _ id: UInt32,
    _ name: String,
    x: CGFloat = 0
) -> Display {
    Display(
        id: DisplayID(id),
        name: name,
        frame: CGRect(x: x, y: 0, width: 100, height: 100)
    )
}

func authoritySpace(
    _ id: UInt64,
    display: String,
    current: Bool = false,
    isUser: Bool = true,
    identity: DesktopIdentity? = nil
) -> NativeSpace {
    NativeSpace(
        id: id,
        displayUUID: display,
        isCurrent: current,
        isUser: isUser,
        identity: identity
    )
}

/// Two displays, two Desktops each: A carries Desktops 1–2
/// (spaces 10, 11), B carries Desktops 3–4 (spaces 20, 21).
func authorityTopology(
    mainCurrent: UInt64,
    secondaryCurrent: UInt64
) -> [NativeSpace] {
    [
        authoritySpace(
            10,
            display: "UUID-A",
            current: mainCurrent == 10
        ),
        authoritySpace(
            11,
            display: "UUID-A",
            current: mainCurrent == 11
        ),
        authoritySpace(
            20,
            display: "UUID-B",
            current: secondaryCurrent == 20
        ),
        authoritySpace(
            21,
            display: "UUID-B",
            current: secondaryCurrent == 21
        ),
    ]
}

/// Pins every machine read a two-display fixture can reach: which
/// display is main, how a `DisplayID` maps to a SkyLight UUID,
/// and the per-display user-space verdict (#670's seam, which the
/// bar-sync arm consults).
@MainActor
func pinTwoDisplays() {
    NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
    NativeSpaces.displayUUIDOverride = { id in
        id == DisplayID(1) ? "UUID-A" : "UUID-B"
    }
    NativeSpaces.currentSpaceIsUserOverride = { _ in true }
}

/// Clears every override the #888 suites may have set.
@MainActor
func resetAuthorityOverrides() {
    NativeSpaces.activeDesktopNumberOverride = nil
    NativeSpaces.activeSpaceIDOverride = nil
    NativeSpaces.activeSpaceIsUserOverride = nil
    NativeSpaces.currentSpaceIsUserOverride = nil
    NativeSpaces.currentSpaceOverride = nil
    NativeSpaces.spacesOverride = nil
    NativeSpaces.mainDisplayUUIDOverride = nil
    NativeSpaces.displayUUIDOverride = nil
}

/// A snapshot over the pinned topology, for the readers that take
/// one (#1230's `virtualSpaceTarget`). Sets `spacesOverride`, so
/// the caller's `resetAuthorityOverrides()` clears it.
@MainActor
func authoritySnapshot(
    mainCurrent: UInt64 = 10,
    secondaryCurrent: UInt64 = 20
) -> DesktopSnapshot {
    NativeSpaces.spacesOverride = authorityTopology(
        mainCurrent: mainCurrent,
        secondaryCurrent: secondaryCurrent
    )
    return NativeSpaces.desktopSnapshot()
}
