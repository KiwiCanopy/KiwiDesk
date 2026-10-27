import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Layouts to cycle opens a popover (#2673): the row's value is a
/// button handing `LayoutCycleList` to a `.popover(item:)` in the
/// Settings chrome, the list draws all seven layouts — the cycle's
/// ticked, the rest below — and the ticked boxes grey at two.
/// Source scans and one model read, all off the main actor but the
/// model case.
@Suite("Layout cycle popover (#2673)")
struct LayoutCyclePopoverTests {
    private func squashed(_ file: String, _ declaration: String) throws
        -> String
    {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Keybindings/"
                    + file
            )
        let text = try SourceScan.strippedSource(at: url)
        let body = try #require(
            SourceScan.declarationBody(after: declaration, in: text)
        )
        #expect(!body.isEmpty)
        return body.split(whereSeparator: \.isWhitespace).joined()
    }

    @Test("the row's value opens the list in a popover")
    func rowOpensPopover() throws {
        let row = try squashed(
            "LayoutCycleRow.swift",
            "struct LayoutCycleRow: View"
        )
        #expect(row.contains(".popover(item:$request,arrowEdge:.bottom)"))
        #expect(
            row.contains(
                "LayoutCycleList(model:model).settingsPopoverChrome()"
            )
        )
        #expect(row.contains(".settingsActionButton()"))
        #expect(
            row.contains(
                ".accessibilityLabel(LayoutCycleWords.title)"
                    + ".accessibilityValue(LayoutCycleWords.spoken("
            )
        )
        // The inline unfold #453 drew is gone.
        #expect(!row.contains("SettingsDisclosureButton"))
        #expect(!row.contains("ifexpanded"))
    }

    @Test("the list draws the cycle, then the rest, greyed at two")
    func listShape() throws {
        let list = try squashed(
            "LayoutCycleList.swift",
            "struct LayoutCycleList: View"
        )
        let body = try #require(
            list.range(of: "varbody:someView{")
        )
        let tail = list[body.upperBound...]
        let ticked = try #require(
            tail.range(
                of: "ForEach(cycle,id:\\.self){modein"
                    + "item(mode,in:true)}"
            )
        )
        let rest = try #require(
            tail.range(
                of: "ForEach(model.modeCycleAddable,id:\\.self){modein"
                    + "item(mode,in:false)}"
            )
        )
        #expect(ticked.lowerBound < rest.lowerBound)
        #expect(
            list.contains(
                "ifcycle{toggle.disabled(!model.modeCycleCanRemove)"
            )
        )
    }

    @Test("the cycle and the rest are every layout, once")
    @MainActor
    func everyLayoutOnce() {
        let model = makeTestModel(core: makeTestCore())
        model.config.modeCycle = [.scrolling, .bsp]
        let drawn = model.config.modeCycle + model.modeCycleAddable
        #expect(drawn.count == LayoutMode.allCases.count)
        #expect(Set(drawn) == Set(LayoutMode.allCases))
        #expect(!model.modeCycleCanRemove)
    }
}
