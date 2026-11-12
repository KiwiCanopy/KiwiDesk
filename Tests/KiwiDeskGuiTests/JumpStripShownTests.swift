import AppKit
import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// When KiwiHub's app strip and the current window show (#3168):
/// the strip off All or under a query; the current window greyed
/// atop All and its own app's tile with nothing typed; a strip
/// that appears or leaves slides the panel. The footer names ← →
/// and the last-app opener on Windows (#3159).
@Suite("KiwiHub strip visibility (#3168)")
@MainActor
struct JumpStripShownTests {
    static var yours: JumpEntry {
        JumpEntry(
            target: .window(WindowID(9)),
            pid: 90,
            app: "Claude",
            title: "KiwiDesk",
            space: "1",
            spaceIcon: nil,
            status: .shown,
            swapBlock: .yours
        )
    }

    private func model(yours: JumpEntry? = Self.yours) -> JumpModel {
        let model = JumpModel(
            snapshot: Self.snapshot(yours: yours),
            icons: [:],
            rowCap: 9,
            pointer: .zero
        )
        model.currentPointer = { .zero }
        return model
    }

    /// Claude, the app you are in, then the strip suite's apps.
    static func snapshot(yours: JumpEntry? = Self.yours) -> JumpSnapshot {
        let base = JumpStripTests.snapshot
        return JumpSnapshot(
            entries: base.entries,
            here: base.here,
            hereIcon: nil,
            apps: [JumpApp(pid: 90, name: "Claude")] + base.apps,
            yours: yours
        )
    }

    @Test("All with an empty field: no strip, the current window atop")
    func calmOpening() {
        let list = JumpList(snapshot: Self.snapshot())
        #expect(!list.stripShown)
        #expect(list.yours == Self.yours)
        #expect(list.drawnRows == list.results.count + 1)
        // Never a result: row 1 stays the window used before.
        #expect(!list.results.contains { $0.entry == Self.yours })
        #expect(list.selection == 0)
    }

    @Test("a query shows the strip on All and hides the current window")
    func typingShowsTheStrip() {
        var list = JumpList(snapshot: Self.snapshot())
        list.setQuery("i")
        #expect(list.tile == 0)
        #expect(list.stripShown)
        #expect(list.yours == nil)
        #expect(list.drawnRows == list.results.count)
    }

    @Test("its own app's tile shows it; another app's does not")
    func ownTileOnly() {
        var list = JumpList(snapshot: Self.snapshot())
        list.pickTile(1)
        #expect(list.stripApp?.name == "Claude")
        #expect(list.stripShown)
        #expect(list.yours == Self.yours)
        #expect(list.results.isEmpty)
        #expect(list.drawnRows == 1)
        list.pickTile(2)
        #expect(list.yours == nil)
        list.pickTile(0)
        #expect(!list.stripShown)
        #expect(list.yours == Self.yours)
    }

    @Test("its app's tile counts it among the app's windows")
    func tileCountsIt() {
        let list = JumpList(snapshot: Self.snapshot())
        #expect(list.windowCount(of: JumpApp(pid: 90, name: "Claude")) == 1)
        #expect(list.windowCount(of: JumpApp(pid: 10, name: "Mail")) == 2)
    }

    @Test("with no window of yours nothing is drawn for it")
    func noWindowNoRow() {
        let list = JumpList(snapshot: Self.snapshot(yours: nil))
        #expect(list.yours == nil)
        #expect(list.drawnRows == list.results.count)
    }

    @Test("a fixture's strip puts your app first")
    func fixtureStripLeadsWithYours() {
        let snapshot = JumpSnapshot(
            entries: JumpStripTests.snapshot.entries,
            here: "1",
            hereIcon: nil,
            yours: Self.yours
        )
        #expect(snapshot.apps.first?.pid == 90)
    }

    @Test("the strip appearing or leaving slides; a move inside snaps")
    func stripToggleSlides() {
        let model = model()
        var slides = 0
        var snaps = 0
        model.onStripToggle = { slides += 1 }
        model.onResultsChange = { snaps += 1 }
        model.handle(.side(1), repeated: false)
        #expect(slides == 1 && snaps == 0)
        model.handle(.side(1), repeated: false)
        #expect(slides == 1 && snaps == 1)
        model.handle(.side(-1), repeated: false)
        model.handle(.side(-1), repeated: false)
        #expect(slides == 2)
        model.query = "i"
        #expect(slides == 3)
    }

    @Test("the row reads as a list row, named on the right")
    func rowWords() {
        LocalizationManager.shared.select("en")
        #expect(JumpStripText.yoursTitle(Self.yours) == "Claude · KiwiDesk")
        #expect(
            JumpStripText.yoursTag(Self.yours) == "Current window · Space 1"
        )
        let untitled = JumpEntry(
            target: .window(WindowID(9)),
            pid: 90,
            app: "Claude",
            title: "",
            space: nil,
            spaceIcon: nil,
            status: .shown
        )
        #expect(JumpStripText.yoursTitle(untitled) == "Claude")
        #expect(JumpStripText.yoursTag(untitled) == "Current window")
        #expect(
            JumpStripText.yoursSpoken(untitled) == "Current window: Claude"
        )
    }

    private func footer(steps: Bool, chord: String?) -> [String] {
        JumpFooter(
            scope: .windows,
            overflows: false,
            stripSteps: steps,
            lastAppChord: chord
        ).hints
    }

    @Test("Windows lists ← → Apps and the opener's chord, last")
    func footerHints() {
        LocalizationManager.shared.select("en")
        let full = footer(steps: true, chord: "⌥⇥")
        let tail = ["← → Apps", "⇥ Shortcuts", "⌥⇥ Next app"]
        #expect(Array(full.suffix(3)) == tail)
        let bare = footer(steps: false, chord: nil)
        #expect(!bare.contains { $0.contains("Apps") })
        #expect(!bare.contains { $0.contains("Next app") })
        #expect(bare.count == full.count - 2)
        // Navigation never lights: ↩ Jump stays the lit hint.
        let lit = JumpFooter(
            scope: .windows,
            overflows: false,
            stripSteps: true,
            lastAppChord: "⌥⇥"
        ).leading
        #expect(lit == 0)
    }

    @Test("the hints reach the other sides not at all")
    func otherSidesUntouched() {
        LocalizationManager.shared.select("en")
        for scope in [JumpScope.shortcuts, .view, .desktops] {
            let hints = JumpFooter(
                scope: scope,
                overflows: false,
                stripSteps: true,
                lastAppChord: "⌥⇥"
            ).hints
            #expect(!hints.contains { $0.contains("Next app") })
            #expect(!hints.contains { $0.contains("Apps") })
        }
    }

    /// The panel takes what the model reports, and reads the
    /// opener's chord at every opening and layer switch.
    @Test("the controller slides on a toggle and reads the chord")
    func controllerWiring() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Jump")
        func squash(_ file: String) throws -> String {
            try SourceScan.strippedSource(
                at: root.appendingPathComponent(file)
            ).split(whereSeparator: \.isWhitespace).joined()
        }
        let controller = try squash("JumpPanelController.swift")
        #expect(
            controller.contains(
                "model.onStripToggle={[weakself]inDispatchQueue.main"
                    + ".async{self?.refit(animated:true)}}"
            )
        )
        #expect(controller.contains("model.lastAppChord=lastAppChord()"))
        #expect(
            try squash("JumpPanelController+Shortcuts.swift")
                .contains("model.lastAppChord=lastAppChord()")
        )
        let view = try squash("JumpPanelView.swift")
        #expect(view.contains("ifmodel.list.stripShown{JumpStripView("))
        // The current window sits in the scrolled list, above the
        // results, and the list's height counts it.
        #expect(
            view.contains(
                "ScrollView{VStack(spacing:0){ifletyours=model.list.yours"
                    + "{JumpYoursLine(entry:yours,"
                    + "icon:model.icons[yours.pid])}"
                    + "rows}"
            )
        )
        #expect(view.contains("rows:model.list.drawnRows"))
        #expect(!view.contains("rows:model.list.results.count"))
        let footer = try squash("JumpPanelView+Footer.swift")
        #expect(footer.contains("lastAppChord:model.lastAppChord"))
    }

    /// The selected tile is the ring alone; only the pointer's
    /// lift takes the hover ground (#1173, #3164, #3210).
    @Test("selection and hover never share the tile's ground")
    func tileGroundIsThePointers() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Jump/JumpStripView.swift"
            )
        let source = try SourceScan.strippedSource(at: file)
            .split(whereSeparator: \.isWhitespace).joined()
        let tile = try #require(
            source.range(of: "structJumpStripTile:View{")
        )
        let rest = source[tile.upperBound...]
        let end = try #require(rest.range(of: "structJumpYoursLine"))
        let body = String(rest[..<end.lowerBound])
        #expect(body.contains("lifted:isLifted)"))
        #expect(
            body.contains(
                "}elseifisLifted{shape.fill(paint.fill(paint.rowHover))}"
            )
        )
        #expect(!body.contains("isSelected||isLifted"))
        #expect(!body.contains("lifted:isSelected"))
    }
}
