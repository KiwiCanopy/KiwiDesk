import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Simple's Mac Checklist block (#3290): only the essentials still
/// open draw, in the checklist's order, as Advanced's own rows; the
/// block folds at 4 of 4; the header is one door into Advanced; and
/// the tour's landing scrolls Simple to it once.
@Suite("Simple Mac Checklist block (#3290)")
@MainActor
struct SimpleMacChecklistTests {
    private let order: [MacChecklistKey] = [
        .rearrangeSpaces, .switchOnActivate, .stageManager, .edgeTiling,
    ]

    @Test("only the open essentials draw, in the checklist's order")
    func openRowsOnly() {
        let none = SimpleMacChecklist.openEssentials(states: [:], ticks: [])
        #expect(none == order)
        let some = SimpleMacChecklist.openEssentials(
            states: [.stageManager: .set, .rearrangeSpaces: .set],
            ticks: []
        )
        #expect(some == [.switchOnActivate, .edgeTiling])
        // A self-ticked unreadable row is done, as the count says.
        let ticked = SimpleMacChecklist.openEssentials(
            states: [.edgeTiling: .unreadable],
            ticks: [.edgeTiling]
        )
        #expect(!ticked.contains(.edgeTiling))
        // An optional setting never joins the block.
        #expect(!none.contains(.clickWallpaper))
        #expect(!none.contains(.doubleClickTitle))
    }

    @Test("every essential set leaves no row")
    func allDoneLeavesNone() {
        let states = Dictionary(
            uniqueKeysWithValues: MacChecklistProgress.essentials.map {
                ($0, MacSettingState.set)
            }
        )
        #expect(
            SimpleMacChecklist.openEssentials(states: states, ticks: [])
                .isEmpty
        )
    }

    private func squashed(_ path: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
            .appendingPathComponent(path)
        let raw = try String(contentsOf: url, encoding: .utf8)
        return SourceScan.stripComments(raw)
            .split(whereSeparator: \.isWhitespace)
            .joined()
    }

    @Test("the block is drawn, folds, opens Advanced, and lands")
    func wiring() throws {
        let screen = try squashed("Settings/SimpleScreen.swift")
        #expect(
            screen.contains(
                "SimpleShortcutCards(model:model).modifier(converge(4,"
                    + "geo.size))SimpleMacChecklist(model:model)"
                    + ".modifier(converge(5,geo.size))"
                    + "HomeSupportStrip(model:model)"
            )
        )
        #expect(
            screen.contains(
                "page(geo).onAppear{landOnChecklist(proxy)}"
                    + ".onChange(of:model.nav.simpleChecklistLanding){"
                    + "landOnChecklist(proxy)}"
            )
        )
        #expect(
            screen.contains(
                "guardmodel.nav.simpleChecklistLandingelse{return}"
                    + "model.nav.simpleChecklistLanding=false"
            )
        )
        #expect(
            screen.contains(
                "proxy.scrollTo(SimpleMacChecklist.anchor,anchor:.top)"
            )
        )
        let block = try squashed(
            "Settings/Components/Simple/SimpleMacChecklist.swift"
        )
        #expect(block.contains("ifopen.isEmpty{allDone}else{"))
        #expect(block.contains("rows(open)"))
        #expect(block.contains("MacSettingRow(model:model,"))
        #expect(block.contains("MacChecklistTicks(model,"))
        #expect(
            block.contains(
                "model.openAdvanced(SettingsAnchor(destination:"
                    + ".macChecklist))"
            )
        )
        #expect(block.contains(".id(Self.anchor)"))
    }
}
