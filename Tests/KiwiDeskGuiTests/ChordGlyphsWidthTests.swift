import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A one-hand sided chord fits the recorder's least width in every
/// catalog (#2601): the side word is translated, so its length is
/// each translator's, and the widest one-hand chord — three
/// modifiers, on either side — is measured in the label's own font
/// against the width the field draws (`labelMinWidth`). A
/// cross-hand chord carries two words and widens its chip past
/// that width, as any long chord does; it is not held here.
@Suite("Sided chords fit the recorder in every locale (#2601)", .serialized)
@MainActor
struct ChordGlyphsWidthTests {
    @Test("a one-hand chord fits in every catalog")
    func oneHandFits() throws {
        defer { LocalizationManager.shared.select("en") }
        let combos = try ["lctrl+lalt+lshift+j", "rctrl+ralt+rshift+j"]
            .map { try #require(KeyCombo.parse($0)) }
        let font = NSFont.monospacedSystemFont(
            ofSize: NSFont.systemFontSize,
            weight: .regular
        )
        let locales = LocaleCatalog.availableLocales() + ["en"]
        #expect(locales.count > 1)
        for locale in locales {
            LocalizationManager.shared.select(locale)
            for combo in combos {
                let drawn = ChordGlyphs.render(
                    combo,
                    layoutChar: { _ in nil }
                )
                #expect(drawn.contains(" "), "\(locale): \(drawn)")
                let width = (drawn as NSString)
                    .size(withAttributes: [.font: font]).width
                #expect(
                    width <= KeyRecorderField.labelMinWidth,
                    "\(locale): “\(drawn)” is \(width) pt"
                )
            }
        }
    }
}
