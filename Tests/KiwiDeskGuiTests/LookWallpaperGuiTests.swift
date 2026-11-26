import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The GUI half of a look's picture (#3478): the look picker draws a
/// card's picture for its own screen, and Use Current Wallpaper
/// narrates every screen it skipped, one line each.
@Suite("Look wallpaper GUI")
@MainActor
struct LookWallpaperGuiTests {
    static let a = String(repeating: "a", count: 64) + ".png"
    static let b = String(repeating: "b", count: 64) + ".png"

    @Test("a card names the picture of the picker's screen")
    func pickerNamesItsScreen() {
        let pictures = LookPickerPictures(
            library: nil,
            maxPixels: 100,
            screen: 2
        )
        let look = ShelfLook(
            name: "Dusk",
            style: [:],
            colors: [:],
            wallpaper: .perScreen([1: Self.a, 2: Self.b])
        )
        let saved = LookPickerEntry(look: look, kind: .saved)
        #expect(pictures.name(of: saved, over: TilingSettings()) == Self.b)
        var worn = TilingSettings()
        worn.lookWallpaper = .all(Self.a)
        let current = LookPickerEntry(
            look: ShelfLook(name: "", style: [:], colors: [:]),
            kind: .current
        )
        #expect(pictures.name(of: current, over: worn) == Self.a)
        #expect(pictures.image(of: saved, over: worn) == nil)
    }

    @Test("Use Current narrates each skipped screen and nothing else")
    func narration() {
        LocalizationManager.shared.select("en")
        #expect(LooksShelf.narrate([1: .stored], look: "Dusk") == nil)
        let text = LooksShelf.narrate(
            [1: .stored, 2: .notPictureFile, 3: .fullScreenSpace],
            look: "Dusk"
        )
        let lines = text?.split(separator: "\n") ?? []
        #expect(lines.count == 2)
        #expect(lines.first?.contains("Screen 2") == true)
        #expect(lines.last?.contains("Screen 3") == true)
    }
}
