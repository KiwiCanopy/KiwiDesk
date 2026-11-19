import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// VoiceOver names a window in macOS full screen on the Desktops
/// side (#3486), and leaves every other window's words alone.
/// `.serialized`: the words are matched in English.
@Suite("Desktops side ▸ full-screen window words", .serialized)
@MainActor
struct DesktopsSpokenFullScreenTests {
    private func window(
        title: String,
        block: DesktopOverview.CarryBlock?
    ) -> DesktopOverview.Window {
        DesktopOverview.Window(
            id: WindowID(4),
            pid: 900_320,
            app: "Safari",
            title: title,
            block: block
        )
    }

    @Test("a full-screen window says so; another does not")
    func fullScreenIsSpoken() {
        LocalizationManager.shared.select("en")
        let full = window(title: "Docs", block: .fullScreen)
        #expect(
            DesktopsText.spoken(full, picked: false)
                == "Safari, Docs, Full Screen"
        )
        let untitled = window(title: "", block: .fullScreen)
        #expect(
            DesktopsText.spoken(untitled, picked: false)
                == "Safari, Full Screen"
        )
        let plain = window(title: "Docs", block: nil)
        #expect(DesktopsText.spoken(plain, picked: false) == "Safari, Docs")
    }
}
