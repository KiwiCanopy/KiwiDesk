import Foundation
import Testing

@testable import KiwiDeskCore

/// The one mapping between the two shortcut bases (#2460): `⌃⌥`
/// plus at most `⇧` and `⌘` onto `✦` with `⇧` and `⌘` kept, the
/// Desktop tier onto `✦⌥`, and back only what that produces.
@Suite("Shortcut base mapping (#2460)")
struct ShortcutBaseTests {
    private func moved(_ combo: String, to base: ShortcutBase) -> String? {
        KeyCombo.parse(combo).flatMap {
            ShortcutBase.moved($0, to: base)?.comboString()
        }
    }

    @Test("the ruled chords move onto ✦, keeping ⇧ and ⌘")
    func forwardTable() {
        let table = [
            ("control+option+f", "hyper+f"),
            ("control+option+left", "hyper+left"),
            ("control+option+shift+left", "hyper+shift+left"),
            ("control+option+3", "hyper+3"),
            ("control+option+shift+3", "hyper+shift+3"),
            ("control+option+command+3", "hyper+command+3"),
            ("control+option+command+left", "hyper+command+left"),
            ("control+option+comma", "hyper+comma"),
            ("control+option+shift+c", "hyper+shift+c"),
        ]
        for (from, to) in table {
            #expect(moved(from, to: .hyper) == to)
            #expect(moved(to, to: .standard) == from)
        }
    }

    /// `✦⇧⌘3` is macOS's screenshot `⇧⌘3` while Hyper is held, and
    /// the screenshot wins (measured 2026-10-20).
    @Test("the Desktop tier takes ✦⌥ + digit, never ✦⇧⌘")
    func desktopTier() {
        #expect(
            moved("control+option+shift+command+3", to: .hyper)
                == "hyper+option+3"
        )
        #expect(
            moved("hyper+option+3", to: .standard)
                == "control+option+shift+command+3"
        )
        #expect(
            moved("control+option+shift+command+k", to: .hyper)
                == "hyper+shift+command+k"
        )
    }

    @Test("what the mapping never produces does not move back")
    func backIsTheInverse() {
        for combo in [
            "hyper+shift+command+3", "hyper+option+k",
            "hyper+control+3", "option+command+1",
        ] {
            #expect(moved(combo, to: .standard) == nil)
        }
    }

    @Test("⌥⌘, a bare key and a row already on ✦ stay")
    func othersStay() {
        for combo in [
            "option+command+2", "option+command+tab", "f5",
            "control+shift+3", "hyper+f",
        ] {
            #expect(moved(combo, to: .hyper) == nil)
        }
    }

    /// Every seeded row round-trips, so `⌃⌥` undoes `✦` exactly.
    @Test("the seed round-trips through ✦")
    func seedRoundTrips() {
        let seed =
            DefaultKeybindings.bindings(
                spaces: (1...10).map { SpaceID(String($0)) },
                resizeStep: 1,
                base: .standard
            )
            + (1...10).compactMap {
                DefaultKeybindings.desktopRow($0, base: .standard)
            }
        for row in seed {
            let there = ShortcutBase.hyper.rebased(row)
            #expect(ShortcutBase.standard.rebased(there) == row)
        }
    }

    @Test("a new Space's digits land on the base")
    func digitTopUpReadsTheBase() {
        let added = DefaultKeybindings.digitTopUp(
            existing: [],
            spaces: [SpaceID("3")],
            base: .hyper
        )
        #expect(
            added.map(\.combo)
                == ["hyper+3", "hyper+shift+3", "hyper+command+3"]
        )
    }

    /// `✦3` registers as a bare 3 while Hyper is held, so a row on
    /// bare 3 holds it.
    @Test("a bare digit holds its ✦ twin")
    func bareDigitHoldsTheHyperTwin() {
        let mine = KeyBinding(combo: "3", lua: "hs.x()", kind: .custom)
        let added = DefaultKeybindings.digitTopUp(
            existing: [mine],
            spaces: [SpaceID("3")],
            base: .hyper
        )
        #expect(!added.map(\.combo).contains("hyper+3"))
    }
}
