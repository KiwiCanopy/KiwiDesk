import AppKit
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The app strip through the panel's model (#3135): ← → reach it on
/// Windows, a click on a dimmed tile does nothing, ↩ on an app with
/// no window reopens it, every chord still picks from the narrowed
/// list, and VoiceOver hears the tile with the row it selects.
@Suite("KiwiHub app strip model")
@MainActor
struct JumpStripModelTests {
    private func model() -> JumpModel {
        LocalizationManager.shared.select("en")
        let model = JumpModel(
            snapshot: JumpStripTests.snapshot,
            icons: [:],
            rowCap: 6,
            pointer: .zero
        )
        model.currentPointer = { .zero }
        return model
    }

    @Test("← → move the strip, and the chords pick from its app")
    func sideMovesTheStrip() {
        LocalizationManager.shared.select("en")
        let model = model()
        var picked: [(String, JumpPick)] = []
        model.onPick = { picked.append(($0.title, $1)) }
        model.handle(.side(1), repeated: false)
        model.handle(.side(1), repeated: false)
        #expect(model.list.stripApp?.name == "Mail")
        model.handle(.step(1), repeated: false)
        model.handle(.pick(moveHere: true), repeated: false)
        model.handle(.swapHere, repeated: false)
        model.handle(.quick(0, moveHere: false), repeated: false)
        #expect(picked.map(\.0) == ["Inbox", "Inbox", "Draft"])
        #expect(picked.map(\.1) == [.moveHere, .swapHere, .jump])
    }

    @Test("↩ on an app with no window reopens it; ⇧↩ does not")
    func reopens() {
        LocalizationManager.shared.select("en")
        let model = model()
        var reopened: [String] = []
        model.onReopen = { reopened.append($0.bundleID ?? "") }
        model.clickTile(3)
        #expect(model.emptyText == "No windows")
        model.handle(.pick(moveHere: true), repeated: false)
        #expect(reopened.isEmpty)
        model.handle(.pick(moveHere: false), repeated: false)
        #expect(reopened == ["com.apple.dt"])
    }

    @Test("a side switch lands Windows back on All")
    func sideSwitchResetsTheStrip() {
        let model = model()
        model.clickTile(2)
        model.setScope(.view)
        model.setScope(.windows)
        #expect(model.list.tile == 0)
        model.openOnLastApp()
        #expect(model.list.stripApp?.name == "Mail")
        #expect(model.list.selected?.entry.title == "Draft")
    }

    @Test("the No windows row's click reopens, as ↩ does")
    func rowClickReopens() {
        let model = model()
        var reopened: [String] = []
        model.onReopen = { reopened.append($0.bundleID ?? "") }
        model.reopenStripApp()
        #expect(reopened.isEmpty)
        model.clickTile(3)
        model.reopenStripApp()
        #expect(reopened == ["com.apple.dt"])
    }

    @Test("a click on a dimmed tile does nothing")
    func dimmedClick() {
        LocalizationManager.shared.select("en")
        let model = model()
        model.query = "inbox"
        model.clickTile(1)
        #expect(model.list.tile == 0)
        model.clickTile(2)
        #expect(model.list.stripApp?.name == "Mail")
        #expect(model.query == "inbox")
    }

    @Test("a strip move announces the tile and its row")
    func announces() {
        LocalizationManager.shared.select("en")
        let model = model()
        var heard: [String] = []
        model.onAnnounce = { heard.append($0) }
        model.handle(.side(1), repeated: false)
        #expect(heard.last?.hasPrefix("Notes: ") == true)
        model.clickTile(3)
        #expect(heard.last == "Xcode: No windows")
    }

    /// The pointer lifts a tile through the model (#2365): a real
    /// move only, never the selected tile, never a dimmed one.
    @Test("a tile lifts on a real pointer move, as a row does")
    func tileHover() {
        let model = model()
        model.hoverTile(2, pointer: .zero)
        #expect(model.hover == nil)
        model.hoverTile(2, pointer: CGPoint(x: 5, y: 5))
        #expect(model.hover == .tile(2))
        #expect(
            JumpHover.lifts(
                .tile(2),
                hover: model.hover,
                selected: false,
                clickable: true
            )
        )
        #expect(
            !JumpHover.lifts(
                .tile(2),
                hover: model.hover,
                selected: true,
                clickable: true
            )
        )
        model.endHover(.tile(2))
        #expect(model.hover == nil)
    }

    @Test("the last-app opener lands on row 1's app, row 1 kept")
    func lastAppOpener() {
        let model = model()
        model.openOnLastApp()
        #expect(model.list.stripApp?.name == "Mail")
        #expect(model.list.selected?.entry.title == "Draft")
    }

    /// The model under a typed query: ← → keep the query and narrow
    /// to the next app with a match (#3135 ▸ Amendment).
    @Test("← → under a query walk the matching apps, query kept")
    func typedArrows() {
        LocalizationManager.shared.select("en")
        let model = model()
        model.query = "inbox"
        model.handle(.side(1), repeated: false)
        #expect(model.query == "inbox")
        #expect(model.list.stripApp?.name == "Mail")
        #expect(model.list.results.map(\.entry.title) == ["Inbox"])
        model.handle(.side(1), repeated: false)
        #expect(model.list.tile == 0)
    }

    /// The controller wires the strip at every opening.
    @Test("the controller wires the strip's reopen")
    func stripWiring() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Jump")
        func squash(_ file: String) throws -> String {
            try SourceScan.strippedSource(
                at: root.appendingPathComponent(file)
            ).split(whereSeparator: \.isWhitespace).joined()
        }
        #expect(
            try squash("JumpPanelController.swift")
                .contains("wireStrip(model)")
        )
        let squashed = try squash("JumpPanelController+Strip.swift")
        // The pick reaches Core's reopen after the panel's close.
        #expect(squashed.contains("model.onReopen={[weakself]appin"))
        #expect(squashed.contains("core.reopenJumpApp(bundleID:bundleID)"))
    }
}
