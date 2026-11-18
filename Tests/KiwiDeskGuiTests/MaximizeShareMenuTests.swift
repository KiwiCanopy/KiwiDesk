import CoreGraphics
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
            let stored = MaximizeLength.fraction(share.value)
            #expect(MaximizeSharePopUp.offMenuShare(stored) == nil)
            #expect(MaximizeSharePopUp.selection(stored) == stored)
        }
        // Typed to the wire's precision, a third is still ⅓.
        #expect(MaximizeSharePopUp.offMenuShare(.fraction(0.3333)) == nil)
        #expect(
            MaximizeSharePopUp.selection(.fraction(0.3333))
                == .fraction(1.0 / 3)
        )
    }

    @Test("A share off the menu is its own checked item")
    func offMenuIsKept() {
        #expect(
            MaximizeSharePopUp.offMenuShare(.fraction(0.4)) == .fraction(0.4)
        )
        #expect(MaximizeSharePopUp.selection(.fraction(0.4)) == .fraction(0.4))
    }

    /// A length is never a preset: it shows as stored, in points
    /// (#3460).
    @Test("A length is its own checked item, shown as stored")
    func lengthIsOffMenu() {
        LocalizationManager.shared.select("en")
        let length = MaximizeLength.points(1600)
        #expect(MaximizeSharePopUp.offMenuShare(length) == length)
        #expect(MaximizeSharePopUp.selection(length) == length)
        #expect(MaximizeSharePopUp.glyph(length) == "1600 pt")
        #expect(MaximizeSharePopUp.spoken(length) == "1600 points")
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
    }

    /// The range is Core's clamp, never a second copy (#1359).
    @Test("Custom clamps to Core's share range")
    func customClamps() {
        let core = MaximizeLength.fractionRange
        #expect(
            MaximizeCustomShare.share(forPercent: 1) == core.lowerBound
        )
        #expect(
            MaximizeCustomShare.share(forPercent: 140) == core.upperBound
        )
    }

    /// A pt length never snaps, and a unit flip converts on the
    /// row's screen, or clears with none (#3460).
    @Test("Custom's unit flip converts on the screen, or clears")
    func customUnitFlip() {
        let region = MaximizeRegion(
            bounds: CGRect(x: 0, y: 25, width: 3200, height: 900)
        )
        var request = MaximizeCustomRequest(
            stored: .fraction(1.0 / 3),
            axis: .height,
            region: region
        )
        // 33 % is the ⅓ the menu shows as 1067 pt.
        request.flip(to: .points)
        #expect(request.number == 1067)
        #expect(request.committed == .points(1067))
        request.flip(to: .percent)
        #expect(request.number == 33)
        // 33 % is ⅓, which is what was stored: nothing to write.
        #expect(request.committed == nil)

        var blind = MaximizeCustomRequest(
            stored: .fraction(0.5),
            axis: .height,
            region: nil
        )
        blind.flip(to: .points)
        #expect(blind.number == 0)
        #expect(blind.committed == nil)
        blind.number = 1100
        #expect(blind.committed == .points(1100))
        blind.cancelled = true
        #expect(blind.committed == nil)
    }

    /// The share pop-up offers Custom… as its last item and opens the
    /// popover from that pick, anchored to itself.
    @Test("the share menu ends in Custom… and opens its popover")
    func menuWiresCustom() throws {
        let source = try popUpSource()
        #expect(
            source.contains(
                "Divider()Text(L(\"layout_defaults.maximize.custom\""
            )
        )
        #expect(source.contains("case.custom:custom=MaximizeCustomRequest("))
        // Custom… is last: nothing follows it inside the menu.
        let tail = try #require(
            source.components(separatedBy: ".tag(Tag.custom)").last?
                .components(separatedBy: ".labelsHidden()").first
        )
        #expect(source.contains(".tag(Tag.custom)"))
        #expect(!tail.contains("Text("))
        #expect(!tail.contains("Divider()"))
        // The lengths are Core's: the pop-up asks the region.
        #expect(source.contains("region.points(of:.fraction(fraction)"))
        #expect(
            source.contains(".popover(item:customBinding)")
        )
        // The draft is written at the dismissal, never at a teardown.
        #expect(
            source.contains(
                "ifnew==nil,letopen=custom,lettyped=open.committed{"
                    + "value=typed"
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
            try popUpSource().components(separatedBy: "varbody:someView{")
                .last?
                .components(separatedBy: "privatevarcustomBinding:").first
        )
        #expect(!menu.contains(".frame(width:"))
        #expect(menu.contains(".controlSize(.large).fixedSize()"))
        let anchor = try #require(
            source.components(separatedBy: "privatefuncanchorMenu(").last
        )
        #expect(anchor.contains(".controlSize(.large).fixedSize()"))
        // The column each cell leads is `MaximizeColumnFitTests`'.
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
        after.maximize.setShare(.fraction(0.4), for: .height, on: .laptop)
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
                == SettingsValueReadout.maximizeShare(
                    before.maximize.heightShare[.laptop]
                )
        )
        #expect(one.newValue == SettingsValueReadout.percent(0.4))
        after.maximize.setShare(.fraction(0.4), for: .height, on: .portrait)
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

    private func popUpSource() throws -> String {
        try source("MaximizeSharePopUp.swift")
    }

    private func shapeRowSource() throws -> String {
        try source("MaximizeShapeRow.swift")
    }

    private func source(_ file: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Layouts/" + file
            )
        return SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "\n", with: "")
    }
}
