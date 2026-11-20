import CoreGraphics
import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A Desktop overview icon hands its title up after the pointer
/// rests on it, and the side draws the hint above its scroll: a
/// tooltip never shows while KiwiDesk is not the active app.
@MainActor
struct DesktopsLineTitleTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private func source(_ path: String) throws -> String {
        let text = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(path)
        )
        #expect(!text.isEmpty)
        return text
    }
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

    /// Above its icon, inside the side's width, and below the icon
    /// where the side's top would cut it — the first line's case.
    @Test("the hint stays inside the side")
    func hintStaysInside() {
        let side = CGSize(width: 400, height: 300)
        let size = CGSize(width: 120, height: 20)
        func at(_ target: CGRect) -> CGPoint {
            DesktopTitleHintLayout.origin(
                of: size,
                over: target,
                in: side,
                4
            )
        }
        let middle = at(CGRect(x: 200, y: 100, width: 30, height: 30))
        #expect(middle == CGPoint(x: 155, y: 76))
        let trailing = at(CGRect(x: 380, y: 100, width: 20, height: 20))
        #expect(trailing.x == CGFloat(276))
        let first = at(CGRect(x: 200, y: 10, width: 30, height: 30))
        #expect(first.y == 44)
    }

    @Test("the side draws the hints its icons hand up")
    func sideDrawsTheHints() throws {
        let icon = try source("Sources/KiwiDesk/Jump/DesktopIconView.swift")
        #expect(icon.contains("key: DesktopTitleHintKey.self"))
        #expect(!icon.contains(".help("))
        let side = try source("Sources/KiwiDesk/Jump/DesktopsSideView.swift")
        #expect(side.contains(".desktopTitleHints()"))
    }
}
