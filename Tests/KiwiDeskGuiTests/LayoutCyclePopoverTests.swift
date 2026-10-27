import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Layouts to cycle opens a popover (#2673): the row's value is a
/// button handing `LayoutCycleList` to a `.popover(item:)` in the
/// Settings chrome, the list draws all seven layouts — the cycle's
/// ticked, the rest below — and the ticked boxes grey at two
/// with their reason, the row keeping the keyboard's row menu.
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
        #expect(row.contains("Button{request=LayoutCycleRequest()}"))
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
        // One ForEach over every layout, so a tick keeps the row's
        // identity and its checkbox's focus.
        #expect(
            tail.contains(
                "ForEach(cycle+addable,id:\\.self)"
                    + "{modeinitem(mode)}"
            )
        )
        // No branch splits a row or its box by ticked state.
        #expect(!list.contains("item(mode,in:"))
        #expect(!list.contains("ifcycle{toggle"))
        // The box sits unbranched in the row, its chain straight.
        #expect(list.contains("}box(mode,in:cycle)Spacer("))
        #expect(
            list.contains(
                ".toggleStyle(.checkbox)"
                    + ".accessibilityLabel(label(mode))"
                    + ".modifier(GreyOut("
            )
        )
        let divider = try #require(
            list.range(
                of: "ifmode==addable.first{Divider()"
            )
        )
        // Every row takes the same chain; at two the ticked rows
        // hold focus for the row menu's chord.
        let row = try #require(
            list.range(
                of: "row(mode,in:ticked).focusable(held(mode))"
                    + ".focused($focused,equals:mode)"
                    + ".accessibilityElement(children:.combine)"
                    + ".rowActions{actions(mode)}"
            )
        )
        // The reason, under the last ticked row while the boxes
        // grey, drawn outside their GreyOut.
        let reason = try #require(
            list.range(
                of: "ifheld(mode),mode==cycle.last{"
                    + "Text(LayoutCycleWords.minimum)"
            )
        )
        #expect(divider.upperBound <= row.lowerBound)
        #expect(row.upperBound <= reason.lowerBound)
        #expect(
            list.contains(
                ".modifier(GreyOut(active:held(mode),"
                    + "help:LayoutCycleWords.minimum))"
            )
        )
        #expect(
            list.contains(
                "!model.modeCycleCanRemove&&cycle.contains(mode)"
            )
        )
    }

    @Test("the cycle and the rest are every layout, once")
    @MainActor
    func everyLayoutOnce() {
        let model = makeTestModel(core: makeTestCore())
        model.config.modeCycle = [.scrolling, .bsp]
        let cycle = model.config.modeCycle
        let drawn = cycle + SettingsModel.cycleAddable(besides: cycle)
        #expect(drawn.count == LayoutMode.allCases.count)
        #expect(Set(drawn) == Set(LayoutMode.allCases))
        #expect(!model.modeCycleCanRemove)
    }
}
