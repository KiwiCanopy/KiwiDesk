import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The tour draws a sided chord as every surface does (#2601): the
/// side as a word before its run, one space before the key, and a
/// sided digit ladder still folds to a range.
@Suite("Tour chords name their side")
@MainActor
struct OnboardingSidedChordTests {
    private func layer(_ combos: [String]) -> KeyLayer {
        KeyLayer(
            name: KeyLayer.defaultName,
            bindings: combos.enumerated().map { index, combo in
                KeyBinding(
                    combo: combo,
                    lua: "KiwiDesk.focus_space("
                        + SpaceLuaArg.quote("\(index + 1)") + ")",
                    kind: .navigation
                )
            }
        )
    }

    private let spaces = ["1", "2", "3"].map { SpaceID($0) }

    @Test("a sided ladder folds to one range, spaced once")
    func sidedLadderFolds() throws {
        LocalizationManager.shared.select("en")
        let chord = try #require(
            OnboardingKeys.digits(
                layer: layer(["lctrl+lalt+1", "lctrl+lalt+2", "lctrl+lalt+3"]),
                command: "focus_space",
                spaces: spaces
            )
        )
        #expect(chord.glyphs == "Left ⌃⌥ 1–3")
    }

    @Test("a sided key alone keeps one space")
    func sidedKeyAlone() {
        LocalizationManager.shared.select("en")
        #expect(OnboardingKeys.keyOnly(combo: "rcmd+j") == "J")
    }
}
