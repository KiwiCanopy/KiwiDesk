import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// KiwiHub's keycaps on Simple (#2777 ruling 4): one cap per
/// modifier, a sided one carrying its side word, then the key, read
/// from `ChordGlyphs.runs` — so a catalog that frames the side with
/// no space, or a hyper chord, keeps every cap. Main-actor spend: a
/// few chord renders.
@Suite("Simple KiwiHub keycaps")
@MainActor
struct SimpleKiwiHubCapsTests {
    private func caps(_ combo: String) -> [String] {
        SimpleKiwiHubKeys.caps(combo).map { cap in
            cap.side.map { "\($0) \(cap.glyph)" } ?? cap.glyph
        }
    }

    @Test("a sided chord keeps a cap per modifier")
    func sidedChord() {
        LocalizationManager.shared.select("en")
        #expect(caps("lctrl+lalt+j") == ["Left ⌃", "Left ⌥", "J"])
        #expect(caps("ctrl+alt+k") == ["⌃", "⌥", "K"])
    }

    /// `ja` frames the side as `左%1$@`, with no space to split on.
    @Test("a side framed without a space keeps every cap")
    func spacelessFrame() {
        LocalizationManager.shared.select("ja")
        defer { LocalizationManager.shared.select("en") }
        let side = ChordGlyphs.sideWord(.left)
        #expect(!side.isEmpty)
        #expect(
            caps("lctrl+lalt+j") == ["\(side) ⌃", "\(side) ⌥", "J"]
        )
    }

    @Test("a hyper chord keeps its hyper cap")
    func hyperChord() {
        LocalizationManager.shared.select("en")
        #expect(caps("hyper+j") == [ComboSymbols.hyperGlyph, "J"])
    }
}
