import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The key sequence panel opens where KiwiHub opens, capped at its
/// sheet height, the end keys scrolling past it (#3175 ▸ Ruling).
@Suite("Key sequence hint placement (#3175)")
@MainActor
struct KeySequenceHintPlacementTests {
    private static func source(_ path: String) throws -> String {
        try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent("Sources/KiwiDesk/" + path)
        )
        .filter { !$0.isWhitespace }
    }

    @Test("The panel stands at KiwiHub's place, never re-centred")
    func kiwiHubsPlace() throws {
        let draw = try Self.source("Shortcuts/KeySequenceHintController.swift")
        #expect(draw.contains("origin:JumpPanelController.origin("))
        #expect(draw.contains("JumpPanelController.clearArea("))
        #expect(draw.contains("sheetCap:JumpPanelController.sheetCap("))
        // Never re-centred, under any spelling.
        let body = try #require(
            SourceScan.declarationBody(
                after: "privatefuncdraw()",
                in: draw
            )
        )
        #expect(!body.contains(".midY"))
        #expect(!body.contains("setFrameOrigin("))
        #expect(body.occurrences(of: "panel.setFrame(") == 1)
        // The wheel scrolls; a click reaches the tap (#1871).
        #expect(draw.contains("panel.ignoresMouseEvents=false"))
    }

    @Test("Only the end keys scroll, through KiwiHub's sheet")
    func endKeysScroll() throws {
        let view = try Self.source("Shortcuts/KeySequenceHintView.swift")
        #expect(view.contains("JumpShortcutsView(sheet:ShortcutsSheet("))
        #expect(view.contains(".moreBelowFade()"))
        #expect(!view.contains("ShortcutsSheetView("))
        let wire = try Self.source("AppDelegate.swift")
        #expect(
            wire.contains(
                "core.onKeySequenceScroll={[weakself]scrollin"
                    + "self?.keySequenceHint.scroll(scroll)}"
            )
        )
    }

    @Test("The end-key cap gives way to each branch row, to a floor")
    func capLessBranches() {
        let key = KeySequenceHint.Key(chord: "W", name: "Windows")
        func cap(branches: Int, sheetCap: CGFloat = 400) -> CGFloat {
            KeySequenceHintView(
                hint: KeySequenceHint(
                    title: "Leader",
                    crumbs: [key],
                    branches: Array(repeating: key, count: branches),
                    endKeys: KeyLayer(name: KeyLayer.defaultName, bindings: [])
                ),
                reference: nil,
                glass: PanelGlass(settings: TilingSettings()),
                sheetCap: sheetCap
            ).endKeyCap
        }
        #expect(cap(branches: 0) == 400)
        let row =
            KeySequenceHintView.branchRowHeight
            + KeySequenceHintView.branchSpacing
        #expect(cap(branches: 1) == 400 - row)
        #expect(cap(branches: 2) < cap(branches: 1))
        #expect(cap(branches: 100) == cap(branches: 200))
        #expect(cap(branches: 100) > 0)
    }

    @Test("A scroll key moves the sheet by lines or pages")
    func scrollTakesSteps() {
        let scroll = KeySequenceHintScroll()
        scroll.take(.step(1))
        #expect(scroll.value.serial == 1 && scroll.value.lines == 1)
        scroll.take(.page(-1))
        #expect(scroll.value.serial == 2)
        #expect(scroll.value.pages == -1 && scroll.value.lines == 0)
    }
}
