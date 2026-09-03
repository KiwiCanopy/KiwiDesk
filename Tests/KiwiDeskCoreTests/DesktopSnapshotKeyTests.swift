import Foundation
import Testing

@testable import KiwiDeskCore

/// The snapshot's three resolves (#1147) — the only door a
/// consumer reaches a `DesktopKey` through, and the reason
/// #1230 adds none of its own. Pure: a fixture topology, no
/// WindowServer.
@Suite("Desktop snapshot keys (#1147)")
struct DesktopSnapshotKeyTests {
    private let stamp = DesktopIdentity(raw: "STAMP-A")

    /// Two displays, four spaces: Desktop 1 stamped, Desktop 2
    /// bare, a fullscreen space between them (so the Mission
    /// Control numbering is not the array index), and the
    /// secondary display showing its own Desktop.
    private func snapshot() -> DesktopSnapshot {
        let spaces = [
            NativeSpace(
                id: 1,
                displayUUID: "MAIN",
                isCurrent: true,
                identity: stamp
            ),
            NativeSpace(
                id: 9,
                displayUUID: "MAIN",
                isCurrent: false,
                isUser: false
            ),
            NativeSpace(
                id: 4,
                displayUUID: "MAIN",
                isCurrent: false
            ),
            NativeSpace(
                id: 7,
                displayUUID: "SIDE",
                isCurrent: true
            ),
        ]
        return DesktopSnapshot(
            authority: 1,
            mainUUID: "MAIN",
            mainCurrentSpace: 1,
            currentSpaces: ["MAIN": 1, "SIDE": 7],
            spaces: spaces
        )
    }

    @Test("a stamped Desktop keys by its identity")
    func stampedKeysByIdentity() {
        #expect(snapshot().key(of: 1) == .identity(stamp))
    }

    /// The fallback is the pre-#1147 key and means exactly what
    /// it meant then: the global Mission Control number, which
    /// counts user Desktops only — 4 is the third space in the
    /// array and the SECOND Desktop.
    @Test("an unstamped Desktop keys by its number")
    func bareKeysByNumber() {
        #expect(snapshot().key(of: 4) == .number(2))
    }

    /// A fullscreen or system space is no Desktop, so it files
    /// nothing — the stamping pass and every consumer read the
    /// same `isUser` verdict (#670).
    @Test("a non-user space keys nothing")
    func nonUserKeysNil() {
        #expect(snapshot().key(of: 9) == nil)
        #expect(snapshot().key(of: 99) == nil)
    }

    @Test("a key resolves back to its Desktop, both shapes")
    func resolvesBack() {
        let snap = snapshot()
        #expect(snap.space(for: .identity(stamp))?.id == 1)
        #expect(snap.space(for: .number(2))?.id == 4)
    }

    /// Absence is not proof: an unplugged display's Desktop and
    /// a deleted one answer the same nil, and a consumer holds
    /// the record dormant rather than pruning on it.
    @Test("an absent Desktop resolves to nil, not to another")
    func absentResolvesNil() {
        let snap = snapshot()
        #expect(
            snap.space(for: .identity(DesktopIdentity(raw: "X")))
                == nil
        )
        #expect(snap.space(for: .number(9)) == nil)
    }

    /// The per-display read #1230 keys by: each display answers
    /// for the Desktop IT is showing, never the main screen's.
    @Test("each display answers with the Desktop it shows")
    func currentKeyIsPerDisplay() {
        let snap = snapshot()
        #expect(snap.currentKey(on: "MAIN") == .identity(stamp))
        #expect(snap.currentKey(on: "SIDE") == .number(3))
        #expect(snap.currentKey(on: "GONE") == nil)
    }
}
