import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A window icon in the Desktop overview draws its own title hint
/// after the pointer rests on it, since a tooltip never shows while
/// KiwiDesk is not the active app and KiwiHub never activates it.
@MainActor
struct DesktopsLineTitleTests {
    @Test("a window's hint names its title, else its app")
    func titleFallsBackToApp() {
        let titled = DesktopOverview.Window(
            id: WindowID(1),
            pid: 900_001,
            app: "Ghostty",
            title: "~/KiwiDesk",
            block: nil
        )
        let bare = DesktopOverview.Window(
            id: WindowID(2),
            pid: 900_001,
            app: "Ghostty",
            title: "",
            block: nil
        )
        #expect(DesktopsText.title(of: titled) == "~/KiwiDesk")
        #expect(DesktopsText.title(of: bare) == "Ghostty")
    }

    @Test("the icon draws the hint on a rested hover, never a tooltip")
    func iconDrawsTheHint() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent(
                "../../Sources/KiwiDesk/Jump/DesktopIconView.swift"
            )
        let source = try String(contentsOf: url, encoding: .utf8)
            .filter { !$0.isWhitespace }
        #expect(!source.isEmpty)
        #expect(source.contains(".overlay(alignment:.top){hint}"))
        #expect(
            source.contains("ifhinted{Text(DesktopsText.title(of:window))")
        )
        #expect(source.contains(".task(id:isHovered){hinted=false"))
        #expect(!source.contains(".help("))
    }
}
