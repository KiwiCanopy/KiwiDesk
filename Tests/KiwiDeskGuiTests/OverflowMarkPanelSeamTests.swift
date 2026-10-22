import Foundation
import Testing

/// An overflow mark's panel is the hover peek's press point's twin
/// (#2235): it reads a press through the shelf panel's one
/// reading, hands it on ahead of the view, and its manager wires it
/// to the same `pressed`. Its effect is a peek closing on a live
/// panel, which no headless suite can press, so it is needled; the
/// shelf panel's half is `BarPeekSeamTests` ▸ `onePressDismissal`.
@Suite("Overflow mark panel seam (#2235)")
struct OverflowMarkPanelSeamTests {
    private static var borders: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore/Borders")
    }

    @Test("the mark's panel is the press point's twin")
    func markPanelPressPoint() throws {
        let overlay = try SourceScan.strippedSource(
            at: Self.borders.appendingPathComponent(
                "OverflowMarkOverlay.swift"
            )
        )
        let send = try #require(
            SourceScan.declarationBody(
                after: "override func sendEvent(",
                in: overlay
            )
        )
        #expect(send.contains("ShelfPanel.pressType(of: event)"))
        #expect(send.contains("Self.closesPeek(hit: hit, type: type)"))
        let press = try #require(send.range(of: "onPress("))
        let forward = try #require(send.range(of: "super.sendEvent("))
        #expect(press.upperBound <= forward.lowerBound)
        let made = try #require(
            SourceScan.declarationBody(after: "func makePanel(", in: overlay)
        )
        #expect(made.contains("panel.onPress = {"))
        let manager = try SourceScan.strippedSource(
            at: Self.borders.appendingPathComponent(
                "OverflowMarkManager.swift"
            )
        )
        #expect(
            manager.contains("self?.peek?.pressed(on: hit, type: type)")
        )
    }

    /// The mark wears the shelf's look, so it stands down with the
    /// shelf on the verdict the bar pass took (#1787, #2448) —
    /// never a second reading of it, nor a part of it — and syncs
    /// at that pass's tail. Which Space a fixture's screen shows is
    /// the host's, so the routing is needled rather than driven.
    @Test("the marks stand down on the bar pass's own verdict")
    func specsReadTheBarVerdict() throws {
        let app = Self.borders.deletingLastPathComponent()
            .appendingPathComponent("App")
        let source = try SourceScan.strippedSource(
            at: app.appendingPathComponent("KiwiCore+OverflowMarks.swift")
        )
        let specs = try #require(
            SourceScan.declarationBody(
                after: "func overflowMarkSpecs(",
                in: source
            )
        )
        #expect(specs.contains("overflowMarks.standingDown"))
        for part in [
            "shelfStandsDown(", "showsMaximized(", "showsPresentation(",
            "isUser",
        ] {
            #expect(!specs.contains(part), "reads \(part) beside it")
        }
        let shelf = try SourceScan.strippedSource(
            at: app.appendingPathComponent("KiwiCore+Shelf.swift")
        )
        let bars = try #require(
            SourceScan.declarationBody(after: "func updateBars(", in: shelf)
        )
        let filed = try #require(
            bars.range(of: "overflowMarks.standingDown = standingDown")
        )
        let synced = try #require(
            bars.range(
                of: "updateOverflowMarks()",
                range: filed.upperBound..<bars.endIndex
            )
        )
        #expect(filed.upperBound <= synced.lowerBound)
    }
}
