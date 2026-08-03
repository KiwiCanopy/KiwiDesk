import Foundation
import Testing

@testable import KiwiDeskCore

/// The first-run keymap the day-one Settings screen rests on
/// (#678 turn 14c).
///
/// That screen's whole claim is "you are already set up —
/// nothing below needs your attention", with no setup task
/// anywhere on it. **It holds only because a real keymap is
/// already seeded**: the welcome tour SHOWS the keys rather
/// than asking the user to create them, and a Shortcuts card
/// reading "18 bound · no conflicts" on a fresh install is a
/// statement of fact about this seed.
///
/// So the thing that would falsify the screen is not a Settings
/// bug at all — it is a seed that quietly stops covering a
/// family. These assert what the tour promises, by the Lua
/// verbs that are the user-visible contract, rather than by
/// counting rows or re-listing what `DefaultKeybindings`
/// generates (both sides of which would come from the same
/// source and prove nothing).
///
/// The Home surface itself belongs to the Home lane, which is
/// last; this pin lands early on purpose, because the seed can
/// regress at any point before then and every existing test
/// would stay green — `DefaultKeybindingsTests` exercises the
/// generator, and the seed-path suites assert spaces and digit
/// ladders, so nothing today reads the keymap a first run
/// actually gets.
@Suite("First-run keymap")
@MainActor
struct FirstRunKeymapTests {
    private func seededBindings() -> [KeyBinding] {
        let core = makeTestCore()
        let config = core.guiConfigSeed()
        let base = config.layers.first { $0.isDefault }
        return base?.bindings ?? []
    }

    /// A first run gets a keymap at all. The floor exists
    /// because every assertion below is a `contains` over this
    /// list, and an empty list satisfies none of them loudly —
    /// it satisfies them by failing, which reads as five
    /// unrelated failures rather than one cause.
    @Test("a first run is seeded with a usable keymap")
    func seedIsNotEmpty() {
        #expect(!seededBindings().isEmpty)
    }

    /// The three families the tour walks. Named by their Lua
    /// verbs, which is what the shortcut rows execute and what
    /// the user reads in the Shortcuts area.
    @Test("focus, swap and space rows are all seeded")
    func coversTheThreeFamilies() {
        let lua = seededBindings().map(\.lua)
        for verb in [
            "KiwiDesk.focus(",
            "KiwiDesk.swap(",
            "KiwiDesk.focus_space",
        ] {
            #expect(
                lua.contains { $0.hasPrefix(verb) },
                Comment(
                    rawValue:
                        "a first run no longer binds \(verb) — the "
                        + "day-one screen claims nothing needs "
                        + "attention, and that stops being true"
                )
            )
        }
    }

    /// Focus is bound in all four directions, not just one. The
    /// family check above passes on a single arrow, which is
    /// exactly the shape a partial regression takes.
    @Test("focus is seeded in all four directions")
    func focusCoversEveryDirection() {
        let lua = Set(seededBindings().map(\.lua))
        for dir in ["left", "down", "up", "right"] {
            #expect(lua.contains("KiwiDesk.focus(\"\(dir)\")"))
        }
    }

    /// Every seeded row carries a label and a combo, because the
    /// tour SHOWS them — an unlabelled binding fires correctly
    /// and cannot be pointed at, which is the one thing the
    /// day-one screen needs it to do.
    @Test("every seeded row is showable")
    func everyRowIsShowable() {
        for binding in seededBindings() {
            #expect(!binding.combo.isEmpty)
            #expect(!binding.label.isEmpty)
        }
    }

    /// No two seeded rows collide, which is what lets the
    /// day-one Shortcuts card say "no conflicts" without
    /// checking anything.
    ///
    /// Compared as PARSED chords, not as strings. `"ctrl+alt+f"`
    /// and `"control+option+f"` are the same chord to
    /// `KeyCombo.parse` and to the user's keyboard, and a raw
    /// string dedup calls them two rows — which is a conflict
    /// shipped under a green test (guard-prover).
    /// `DefaultKeybindings.digitTopUp` already parses for this
    /// reason; the guard had not caught up.
    @Test("the seeded rows carry no conflicts")
    func noSeededConflicts() {
        let parsed = seededBindings().compactMap {
            KeyCombo.parse($0.combo)
        }
        #expect(parsed.count == seededBindings().count)
        #expect(parsed.count == Set(parsed).count)
    }
}
