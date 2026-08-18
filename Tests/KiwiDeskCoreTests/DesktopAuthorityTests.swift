import Foundation
import Testing

@testable import KiwiDeskCore

/// #888's definition: "Desktop N activates" means the MAIN
/// display's current Desktop became N.
///
/// Serialized, and every body synchronous `@MainActor` — the
/// fixture drives process-global DEBUG overrides, and
/// `.serialized` binds per suite, so set-assert-reset in one hop
/// is what keeps the #888 suites from racing each other. An
/// `async` body opens the window the serialization does not
/// close. The fixture is `DesktopAuthorityFixture.swift`.
@Suite("Main-display Desktop authority (#888)", .serialized)
@MainActor
struct DesktopAuthorityTests {
    @Test("The active Desktop is the main display's current one")
    func mainAnswers() {
        defer { resetAuthorityOverrides() }
        NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        #expect(NativeSpaces.activeDesktopNumber() == 1)
        // A secondary display's swipe moves the answer nowhere.
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 21
        )
        #expect(NativeSpaces.activeDesktopNumber() == 1)
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 11,
            secondaryCurrent: 21
        )
        #expect(NativeSpaces.activeDesktopNumber() == 2)
    }

    @Test("An unresolvable main display falls back to the global read")
    func fallsBack() {
        defer { resetAuthorityOverrides() }
        // Main UUID absent from the snapshot (shared mode's
        // synthetic managed display, an unplugged screen): the
        // global active space answers. `activeSpaceIDOverride` is
        // pinned because that fallback reads it — unpinned, this
        // fixture would reach the live WindowServer.
        NativeSpaces.mainDisplayUUIDOverride = "UUID-X"
        NativeSpaces.activeSpaceIDOverride = 20
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        #expect(NativeSpaces.activeDesktopNumber() == 3)
    }

    @Test("A fullscreen Desktop on the main display is nil")
    func fullscreenIsNil() {
        defer { resetAuthorityOverrides() }
        NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
        NativeSpaces.spacesOverride = [
            authoritySpace(10, display: "UUID-A"),
            authoritySpace(
                99,
                display: "UUID-A",
                current: true,
                isUser: false
            ),
            authoritySpace(20, display: "UUID-B", current: true),
        ]
        #expect(NativeSpaces.activeDesktopNumber() == nil)
    }

    /// The snapshot answers the authority AND the per-display
    /// current Spaces from ONE reading — the property the switch
    /// handler and the event emit both rest on, since two
    /// readings taken moments apart can disagree about which
    /// display switched.
    @Test("One snapshot carries the authority and every display")
    func snapshotIsOneReading() {
        defer { resetAuthorityOverrides() }
        NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 11,
            secondaryCurrent: 20
        )
        let snapshot = NativeSpaces.desktopSnapshot()
        #expect(snapshot.authority == 2)
        #expect(snapshot.mainUUID == "UUID-A")
        #expect(snapshot.currentSpaces["UUID-A"] == 11)
        #expect(snapshot.currentSpaces["UUID-B"] == 20)
        // Numbering inside the snapshot, so a consumer cannot
        // number a Space in a topology the authority was not
        // counted in.
        #expect(snapshot.number(of: 20) == 3)
    }

    /// The #670 verdict, per display and inside the snapshot: the
    /// bar-sync arm asks about the MAIN display, not about
    /// whatever holds focus.
    @Test("The user-space verdict answers per display")
    func verdictIsPerDisplay() {
        defer { resetAuthorityOverrides() }
        NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
        NativeSpaces.spacesOverride = [
            authoritySpace(
                99,
                display: "UUID-A",
                current: true,
                isUser: false
            ),
            authoritySpace(20, display: "UUID-B", current: true),
        ]
        let snapshot = NativeSpaces.desktopSnapshot()
        #expect(!snapshot.currentSpaceIsUser(on: "UUID-A"))
        #expect(snapshot.currentSpaceIsUser(on: "UUID-B"))
        // An unknown display counts as user: standing down needs
        // positive evidence, never a lookup miss.
        #expect(snapshot.currentSpaceIsUser(on: "UUID-X"))
        #expect(snapshot.currentSpaceIsUser(on: nil))
    }
}
