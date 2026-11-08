import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A Maximize share pop-up offers ¼ ⅓ ½ ⅔ ¾ and Custom… (#3062,
/// owner 2026-11-08); a stored share outside them shows as one extra
/// checked item and goes once a fraction replaces it.
@Suite("Maximize share pop-up items (#3062)")
@MainActor
struct MaximizeShareMenuTests {
    @Test("A preset share adds no item and checks its fraction")
    func presetAddsNothing() {
        for share in FractionChips.shares {
            #expect(MaximizeShapeRow.offMenuShare(share.value) == nil)
            #expect(MaximizeShapeRow.selection(share.value) == share.value)
        }
        // Typed to the wire's precision, a third is still ⅓.
        #expect(MaximizeShapeRow.offMenuShare(0.3333) == nil)
        #expect(MaximizeShapeRow.selection(0.3333) == 1.0 / 3)
    }

    @Test("A share off the menu is its own checked item")
    func offMenuIsKept() {
        #expect(MaximizeShapeRow.offMenuShare(0.4) == 0.4)
        #expect(MaximizeShapeRow.selection(0.4) == 0.4)
    }

    /// A typed percent that rounds to a fraction stores the fraction
    /// itself, so the menu checks it (#3062, ruling amendment 2).
    @Test("Custom snaps a menu percent onto its fraction")
    func customSnaps() {
        for share in FractionChips.shares {
            let percent = MaximizeCustomShare.percent(of: share.value)
            #expect(
                MaximizeCustomShare.share(forPercent: percent)
                    == share.value
            )
        }
        #expect(MaximizeCustomShare.share(forPercent: 33) == 1.0 / 3)
        #expect(MaximizeCustomShare.share(forPercent: 40) == 0.4)
        #expect(MaximizeShapeRow.offMenuShare(0.4) == 0.4)
    }

    /// The range is Core's clamp, never a second copy (#1359).
    @Test("Custom clamps to Core's share range")
    func customClamps() {
        let core = MaximizeShape.shareRange
        #expect(
            MaximizeCustomShare.share(forPercent: 1) == core.lowerBound
        )
        #expect(
            MaximizeCustomShare.share(forPercent: 140) == core.upperBound
        )

        #expect(MaximizeCustomShare.tag < 0)
    }

    /// The share pop-up offers Custom… as its last item and opens the
    /// popover from that pick, anchored to itself.
    @Test("the share menu ends in Custom… and opens its popover")
    func menuWiresCustom() throws {
        let source = try shapeRowSource()
        #expect(
            source.contains(
                "Divider()Text(L(\"layout_defaults.maximize.custom\""
            )
        )
        #expect(source.contains("ifpicked==MaximizeCustomShare.tag{"))
        #expect(
            source.contains(".popover(item:customBinding(key,value:value))")
        )
        // The draft is written at the dismissal, never at a teardown.
        #expect(
            source.contains(
                "ifnew==nil,letopen=custom[key],!open.cancelled,"
                    + "open.percent!=open.seed{"
                    + "value.wrappedValue=MaximizeCustomShare.share("
            )
        )
    }

    /// A menu pop-up draws at its own width whatever frame it gets,
    /// so a fixed frame centres it and a column's pills start apart:
    /// every cell takes its natural width on the column's leading
    /// edge, as the From column does.
    @Test("every cell sits on its column's leading edge")
    func cellsLeadTheirColumn() throws {
        let source = try shapeRowSource()
        let menu = try #require(
            source.components(separatedBy: "privatefuncshareMenu(").last?
                .components(separatedBy: "privatefunccustomBinding(").first
        )
        #expect(!menu.contains(".frame(width:"))
        #expect(menu.contains(".controlSize(.large).fixedSize()"))
        let anchor = try #require(
            source.components(separatedBy: "privatefuncanchorMenu(").last
        )
        #expect(anchor.contains(".controlSize(.large).fixedSize()"))
        #expect(
            source.contains(
                "cell(key).frame(width:Self.columnWidth,alignment:.leading)"
            )
        )
    }

    /// The popover's "%" sits beside "Share" in a row laid out at
    /// its fitting width, where an unfixed unit was squeezed out
    /// (owner eyeball, 2026-11-08).
    @Test("the stepper's unit keeps its width")
    func unitKeepsItsWidth() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Common/"
                    + "StepperRow.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "\n", with: "")
        #expect(
            source.contains(
                "Text(suffix).foregroundStyle(.secondary).fixedSize()"
            )
        )
    }

    /// A step shows in a focused field: the arrows and ↑/↓ write the
    /// field's text with the value, which the field's own outside-
    /// change refresh skips while focused (owner eyeball, 2026-11-08).
    @Test("a step updates the focused field's text")
    func stepUpdatesTheField() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Common/"
                    + "StepperRow.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "\n", with: "")
        #expect(source.contains("Stepper(value:stepped,in:range,step:step)"))
        #expect(source.contains("set:{value=$0text=\"\\($0)\"}"))
        #expect(source.contains(".onKeyPress(.upArrow){step(by:step)}"))
        #expect(source.contains(".onKeyPress(.downArrow){step(by:-step)}"))
    }

    /// The pill's row names the changed shape in its label, so its
    /// readout is the values alone and fits the value column (owner
    /// eyeball, 2026-11-08); several shapes read as the first "+N".
    @Test("a Maximize diff row names its shape in the label")
    func diffRowNamesItsShape() throws {
        LocalizationManager.shared.select("en")
        let before = TilingSettings()
        var after = before
        after.maximize.setShare(0.4, for: .height, on: .laptop)
        let key = SettingKey.behaviour(.maximizeHeightShare)
        let one = try #require(
            SettingsValueReadout.maximizeRows(
                .maximizeHeightShare,
                key,
                before,
                after
            ).first
        )
        #expect(one.label.hasSuffix(", Laptop"))
        #expect(
            one.oldValue
                == SettingsValueReadout.percent(
                    before.maximize.heightShare[.laptop]
                )
        )
        #expect(one.newValue == SettingsValueReadout.percent(0.4))
        after.maximize.setShare(0.4, for: .height, on: .portrait)
        let two = try #require(
            SettingsValueReadout.maximizeRows(
                .maximizeHeightShare,
                key,
                before,
                after
            ).first
        )
        #expect(two.label.hasSuffix(", Laptop +1"))
        #expect(two.newValue == SettingsValueReadout.percent(0.4))
        let rest = try #require(
            SettingsValueReadout.maximizeRows(
                .maximizeHeightShare,
                key,
                before,
                before
            ).first
        )
        #expect(rest.label.hasSuffix(", Laptop"))
    }

    private func shapeRowSource() throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Layouts/"
                    + "MaximizeShapeRow.swift"
            )
        return SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "\n", with: "")
    }
}
