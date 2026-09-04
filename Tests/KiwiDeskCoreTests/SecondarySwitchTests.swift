import Foundation
import Testing

@testable import KiwiDeskCore

/// A secondary display's Desktop switch retiles its arrived
/// windows but selects no profile and moves no Space (#888) —
/// and the arm that decides so never rests on a nil number.
///
/// Serialized, synchronous bodies: see `DesktopAuthorityTests`
/// for why, and `DesktopAuthorityFixture.swift` for the pins.
@Suite("Secondary-display switches (#888)", .serialized)
@MainActor
struct SecondarySwitchTests {
    /// A two-display core on Desktop 1 with "Bound" bound to
    /// Desktop 1 and "Loaded" manually active — the state in
    /// which a binding re-apply is observable.
    private func makeSeparateCore() -> KiwiCore {
        let core = makeAuthorityCore()
        connectAuthority(
            core,
            [
                authorityDisplay(1, "A"),
                authorityDisplay(2, "B", x: 100),
            ]
        )
        pinTwoDisplays()
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        core.execute("save_profile", args: [.string("Bound")])
        core.execute("save_profile", args: [.string("Loaded")])
        core.execute(
            "bind_profile_to_desktop",
            args: [.number(1), .string("Bound")]
        )
        core.execute("load_profile", args: [.string("Loaded")])
        core.lastDesktop = .number(1)
        core.desktopMemory.lastDisplaySpaces = [
            "UUID-A": 10, "UUID-B": 20,
        ]
        return core
    }

    @Test("A secondary swipe never selects a profile")
    func secondaryNeverSelects() {
        defer { resetAuthorityOverrides() }
        let core = makeSeparateCore()
        #expect(core.profiles.currentName == "Loaded")
        // B swipes 20 → 21; the main display stays on Desktop 1.
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 21
        )
        core.handleDesktopChange()
        // Without the #888 arm, applyDesktopBinding would
        // snap the manually-loaded profile back to "Bound".
        #expect(core.profiles.currentName == "Loaded")
        #expect(core.desktopMemory.virtualSpaces.isEmpty)
    }

    @Test("A main-display switch still applies the binding")
    func mainStillApplies() {
        defer { resetAuthorityOverrides() }
        let core = makeSeparateCore()
        core.execute(
            "bind_profile_to_desktop",
            args: [.number(2), .string("Bound")]
        )
        // Main swipes Desktop 1 → 2.
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 11,
            secondaryCurrent: 20
        )
        core.handleDesktopChange()
        #expect(core.profiles.currentName == "Bound")
        // And the outgoing Desktop remembered its Space, keyed
        // under the main display.
        #expect(
            core.desktopMemory.virtualSpaces[.number(1)] != nil
        )
    }

    /// The arm's own decision, asserted directly: the branch it
    /// gates force-retiles, and a retile needs a screen, so the
    /// predicate is what a headless host can hold.
    ///
    /// **The `nil` case is the defect this closes** (review,
    /// 2026-08-18). A main display on a fullscreen space answers
    /// nil, and `nil == lastDesktop` was satisfied by the
    /// previous nil — so the arm claimed a secondary switch it
    /// had no evidence for and force-retiled where the pre-#888
    /// handler and `desktopSettle` stand down. Same shape
    /// without SkyLight, where every switch answers nil. That is
    /// the #670 conflation: the fullscreen verdict is `isUser`,
    /// never the nil Desktop.
    @Test("The secondary verdict, including its nil case")
    func secondaryVerdict() {
        // A secondary display moved while the authority held.
        #expect(
            KiwiCore.isSecondarySwitch(
                authority: .number(1),
                lastAuthority: .number(1),
                changed: ["UUID-B"],
                mainUUID: "UUID-A"
            )
        )
        // The main display moved: not a secondary switch, even
        // though it also changed a Space.
        #expect(
            !KiwiCore.isSecondarySwitch(
                authority: .number(2),
                lastAuthority: .number(1),
                changed: ["UUID-A"],
                mainUUID: "UUID-A"
            )
        )
        // Nothing diffed — a repeated notification.
        #expect(
            !KiwiCore.isSecondarySwitch(
                authority: .number(1),
                lastAuthority: .number(1),
                changed: [],
                mainUUID: "UUID-A"
            )
        )
        // ONLY the main display diffed, with the authority
        // unchanged — a space deleted and re-created under the
        // same number, a re-arrangement. The one input shape
        // that isolates the `mainUUID` exclusion: without it
        // this reads as a secondary switch and stands the
        // profile down on the main display's own switch
        // (`guard-prover` found no case reaching that clause,
        // 2026-08-18).
        #expect(
            !KiwiCore.isSecondarySwitch(
                authority: .number(1),
                lastAuthority: .number(1),
                changed: ["UUID-A"],
                mainUUID: "UUID-A"
            )
        )
        // The nil authority: fullscreen main display, or no
        // SkyLight. Falls through to the main arm whatever the
        // diff says.
        #expect(
            !KiwiCore.isSecondarySwitch(
                authority: nil,
                lastAuthority: nil,
                changed: ["UUID-B"],
                mainUUID: "UUID-A"
            )
        )
        // And nil never counts as "unchanged" against a live
        // previous Desktop either.
        #expect(
            !KiwiCore.isSecondarySwitch(
                authority: nil,
                lastAuthority: .number(1),
                changed: ["UUID-B"],
                mainUUID: "UUID-A"
            )
        )
    }

    /// The diff is taken ONCE per switch: a second call would
    /// compare against the stamp the first one wrote and report
    /// nothing changed, which is how the handler's arm and the
    /// event could name different displays.
    @Test("The switched-display diff re-stamps as it reads")
    func diffStampsOnce() {
        defer { resetAuthorityOverrides() }
        let core = makeSeparateCore()
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 21
        )
        let snapshot = NativeSpaces.desktopSnapshot()
        #expect(
            core.switchedDisplays(in: snapshot).changed == ["UUID-B"]
        )
        #expect(core.switchedDisplays(in: snapshot).changed.isEmpty)
    }
}
